require 'nokogiri'
require 'open-uri'
require 'tzinfo'

class VotesLiveHouse
  
  def self.run(options = {})
    year = Time.now.year
    
    count = 0
    missing_ids = []
    bad_votes = []
    bad_fetches = []
    
    # make lookups faster later by caching a hash of legislators from which we can lookup bioguide_ids
    legislators = {}
    Legislator.only(Utils.legislator_fields).all.each do |legislator|
      legislators[legislator.bioguide_id] = Utils.legislator_for legislator
    end
    
    latest_new_roll = nil
    begin
      latest_new_roll = latest_new_roll year
    rescue Timeout::Error
      Report.warning self, "Timeout error on fetching the listing page, can't go on."
      return
    end
    
    if latest_new_roll.nil?
      Report.failure self, "Failed to find the latest new roll on the clerk's page, can't go on."
      return
    end
    
    # check last 50 rolls, see if any are missing from our database
    to_fetch = []
    (latest_new_roll-49).upto(latest_new_roll) do |number|
      if (number > 0) and (Vote.where(:roll_id => "h#{number}-#{year}").first == nil)
        to_fetch << number
      end
    end
    
    if to_fetch.empty?
      Report.success self, "No new rolls for the House for #{year}, latest one is #{latest_new_roll}."
      return
    end
    
    # debug
    # to_fetch = [884]
    # year = 2009
    
    # get each new roll
    to_fetch.each do |number|
      url = "http://clerk.house.gov/evs/#{year}/roll#{zero_prefix number}.xml"
      
      doc = nil
      begin
        doc = Nokogiri::XML open(url)
      rescue Timeout::Error, OpenURI::HTTPError
        doc = nil
      end
      
      if doc
        roll_id = "h#{number}-#{year}"
        session = doc.at(:congress).inner_text.to_i
        
        bill_id = bill_id_for doc, session
        amendment_id = amendment_id_for doc, bill_id
        
        voter_ids, voters = votes_for doc, legislators, missing_ids
        roll_type = doc.at("vote-question").inner_text
        
        vote = Vote.new :roll_id => roll_id
        vote.attributes = {
          :vote_type => Utils.vote_type_for(roll_type),
          :how => "roll",
          :chamber => "house",
          :year => year,
          :number => number,
          
          :session => session,
          
          :roll_type => roll_type,
          :question => roll_type,
          :result => doc.at("vote-result").inner_text,
          :required => required_for(doc),
          
          :voted_at => voted_at_for(doc),
          :voter_ids => voter_ids,
          :voters => voters,
          :vote_breakdown => Utils.vote_breakdown_for(voters),
        }
        
        if bill_id
          if bill = Utils.bill_for(bill_id)
            vote.attributes = {
              :bill_id => bill_id,
              :bill => bill
            }
          else
            Report.warning self, "Found bill_id #{bill_id} on House roll no. #{number}, which isn't in the database."
          end
        end
        
        if amendment_id
          if amendment = Amendment.where(:amendment_id => amendment_id).only(Utils.amendment_fields).first
            vote.attributes = {
              :amendment_id => amendment_id,
              :amendment => Utils.amendment_for(amendment)
            }
          else
            Report.warning self, "On roll #{roll_id}, found amendment_id #{amendment_id}, which isn't in the database."
          end
        end
        
        if vote.save
          count += 1
          puts "[#{roll_id}] Saved successfully"
        else
          bad_votes << {:error_messages => vote.errors.full_messages, :roll_id => roll_id}
          puts "[#{roll_id}] Error saving, will file report"
        end
        
      else
        bad_fetches << {:number => number, :url => url}
      end
    end
    
    if bad_votes.any?
      Report.failure self, "Failed to save #{bad_votes.size} roll calls. Attached the last failed roll's attributes and error messages.", {:bad_vote => bad_votes.last}
    end
    
    if missing_ids.any?
      missing_ids = missing_ids.uniq
      Report.warning self, "Found #{missing_ids.size} missing Bioguide IDs, attached. Vote counts on roll calls may be inaccurate until these are fixed.", {:missing_ids => missing_ids}
    end
    
    if bad_fetches.any?
      Report.warning self, "Error on fetching #{bad_fetches.size} House roll(s), skipping and going onto the next one. Last number: #{bad_fetches.last[:number]}, last URL: #{bad_fetches.last[:url]}", :bad_fetches => bad_fetches
    end
    
    Report.success self, "Fetched #{count} new live roll calls from the House Clerk website."
  end
  
  
  # latest roll number on the House Clerk's listing of latest votes
  def self.latest_new_roll(year)
    url = "http://clerk.house.gov/evs/#{year}/index.asp"
    doc = Nokogiri::HTML open(url)
    element = doc.css("tr td a").first
    if element and element.text.present?
      number = element.text.to_i
      if number > 0
        number
      else
        nil
      end
    else
      nil
    end
  end
  
  def self.required_for(doc)
    if doc.at("vote-type").inner_text =~ /^2\/3/i
      "2/3"
    else
      "1/2"
    end
  end
  
  def self.vote_mapping
    {
      "Aye" => "Yea",
      "No" => "Nay"
    }
  end
  
  def self.votes_for(doc, legislators, missing_ids)
    voter_ids = {}
    voters = {}
    
    doc.search("//vote-data/recorded-vote").each do |elem|
      vote = (elem / 'vote').text
      vote = vote_mapping[vote] || vote # check to see if it should be standardized
      
      bioguide_id = (elem / 'legislator').first['name-id']
      
      if legislators[bioguide_id]
        voter = legislators[bioguide_id]
        bioguide_id = voter[:bioguide_id]
        voter_ids[bioguide_id] = vote
        voters[bioguide_id] = {:vote => vote, :voter => voter}
      else
        if bioguide_id.to_i == 0
          missing_ids << [bioguide_id, filename]
        else
          missing_ids << bioguide_id
        end
      end
    end
    
    [voter_ids, voters]
  end
  
  def self.bill_id_for(doc, session)
    elem = doc.at 'legis-num'
    if elem
      code = elem.text.strip.gsub(' ', '').downcase
      type = code.gsub /\d/, ''
      number = code.gsub type, ''
      
      type.gsub! "hconres", "hcres" # house uses H CON RES
      
      if !["hr", "hres", "hjres", "hcres", "s", "sres", "sjres", "scres"].include?(type)
        nil
      else
        "#{type}#{number}-#{session}"
      end
    else
      nil
    end
  end
  
  def self.amendment_id_for(doc, bill_id)
    if bill_id and (elem = doc.at("amendment-num"))
      if result = Amendment.where(:bill_id => bill_id, :bill_sequence => elem.text.to_i).only(:amendment_id).first
        result['amendment_id']
      end
    end
  end
  
  def self.zero_prefix(number)
    if number < 10
      "00#{number}"
    elsif number < 100
      "0#{number}"
    else
      number
    end
  end
  
  def self.voted_at_for(doc)
    # make sure we're set to EST
    Time.zone = ActiveSupport::TimeZone.find_tzinfo "America/New_York"
    
    datestamp = doc.at("action-date").inner_text
    timestamp = doc.at("action-time").inner_text
    
    date = Time.parse datestamp
    time = Time.parse timestamp
    
    Time.local date.year, date.month, date.day, time.hour, time.min, time.sec
  end
  
end

require 'net/http'

# Shorten timeout in Net::HTTP
module Net
  class HTTP
    alias old_initialize initialize

    def initialize(*args)
        old_initialize(*args)
        @read_timeout = 8 # 8 seconds
    end
  end
end