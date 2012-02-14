require 'nokogiri'
require 'open-uri'
require 'tzinfo'

class VotesLiveSenate
  
  def self.run(options = {})
    count = 0
    missing_legislators = []
    bad_votes = []
    http_errors = []
    
    missing_bill_ids = []
    missing_amendment_ids = []

    votes_client = Searchable.client_for 'votes'
    
    # will be referenced by LIS ID as a cache built up as we parse through votes
    legislators = {}
    
    latest_roll = nil
    session = nil
    subsession = nil
    begin
      latest_roll, session, subsession = latest_roll_info
    rescue Timeout::Error, Errno::ECONNRESET, Errno::ETIMEDOUT, Errno::ENETUNREACH
      Report.note self, "Timeout error on fetching the listing page, can't go on."
      return
    end
    
    unless latest_roll and session and subsession
      Report.note self, "Couldn't figure out latest roll, or session, or subsession, from the Senate page, aborting", {:latest_roll => latest_roll, :session => session, :subsession => subsession}
      return
    end
    
    if session != Utils.current_session
      Report.note self, "Senate hasn't had a roll call for the current session (#{Utils.current_session}) yet."
      return
    end
    
    year = Time.now.year
    
    # check last 50 rolls, see if any are missing from our database
    to_fetch = []
    (latest_roll-50).upto(latest_roll) do |number|
      if (number > 0) and Vote.where(:roll_id => "s#{number}-#{year}").first.nil?
        to_fetch << number
      end
    end
    
    if to_fetch.empty?
      Report.success self, "No new rolls for the Senate for #{year}, latest one is #{latest_roll}."
      return
    end
    
    # debug
    # to_fetch = [210]
    # year = 2011
    # session = 112
    # subsession = 1
    
    # get each new roll
    to_fetch.each do |number|
      url = url_for number, session, subsession
      
      doc = nil
      exception = nil
      begin
        doc = Nokogiri::XML open(url)
      rescue Timeout::Error, OpenURI::HTTPError => e
        doc = nil
        exception = e
      end
      
      if doc
        roll_id = "s#{number}-#{year}"
        bill_id = bill_id_for doc, session
        amendment_id = amendment_id_for doc, session
        voter_ids, voters = votes_for doc, legislators, missing_legislators
        
        roll_type = doc.at("question").text
        question = doc.at("vote_question_text").text
        result = doc.at("vote_result").text
        
        vote = Vote.new :roll_id => roll_id
        vote.attributes = {
          :vote_type => Utils.vote_type_for(roll_type, question),
          :how => "roll",
          :chamber => "senate",
          :year => year,
          :number => number,
          
          :session => session,
          
          :roll_type => roll_type,
          :question => question,
          :result => result,
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
          elsif bill = create_bill(bill_id, doc)
            vote.attributes = {
              :bill_id => bill_id,
              :bill => Utils.bill_for(bill)
            }
          else
            missing_bill_ids << {:roll_id => roll_id, :bill_id => bill_id}
          end
        end
        
        # for now, only bother with amendments on bills
        if bill_id and amendment_id
          if amendment = Amendment.where(:amendment_id => amendment_id).only(Utils.amendment_fields).first
            vote.attributes = {
              :amendment_id => amendment_id,
              :amendment => Utils.amendment_for(amendment)
            }
          else
            missing_amendment_ids << {:roll_id => roll_id, :amendment_id => amendment_id}
          end
        end
        
        if vote.save
          # replicate it in ElasticSearch
          Utils.search_index_vote! votes_client, roll_id, vote.attributes

          count += 1
          puts "[#{roll_id}] Saved successfully"
        else
          bad_votes << {:error_messages => vote.errors.full_messages, :roll_id => roll_id}
          puts "[#{roll_id}] Error saving, will file report"
        end
        
      else
        http_errors << {:number => number, :exception => exception.message}
      end
    end

    votes_client.refresh
    
    if bad_votes.any?
      Report.failure self, "Failed to save #{bad_votes.size} roll calls. Attached the last failed roll's attributes and error messages.", {:bad_vote => bad_votes.last}
    end
    
    if missing_legislators.any?
      Report.warning self, "Couldn't look up #{missing_legislators.size} legislators in Senate roll call listing. Vote counts on roll calls may be inaccurate until these are fixed.", {:missing_legislators => missing_legislators}
    end
    
    if missing_bill_ids.any?
      Report.warning self, "Found #{missing_bill_ids.size} missing bill_id's while processing votes.", {:missing_bill_ids => missing_bill_ids}
    end
    
    if missing_amendment_ids.any?
      Report.warning self, "Found #{missing_amendment_ids.size} missing amendment_id's while processing votes.", {:missing_amendment_ids => missing_amendment_ids}
    end
    
    if http_errors.any?
      Report.note self, "HTTP error on fetching #{http_errors.size} Senate roll(s), skipped them.", :http_errors => http_errors
    end
    
    Report.success self, "Fetched #{count} new live roll calls from the Senate website."
  end
  
  
  # find the latest roll call number listed on the Senate roll call vote page
  def self.latest_roll_info
    url = "http://www.senate.gov/pagelayout/legislative/a_three_sections_with_teasers/votes.htm"
    
    begin
      doc = Nokogiri::HTML open(url)
    rescue Timeout::Error, OpenURI::HTTPError => ex
      return nil
    end
    
    element = doc.css("td.contenttext a").first
    
    if element and element.text.present?
      number = element.text.to_i
      
      return nil unless href = element['href']
      
      if session = href.match(/congress=(\d+)/i)
        session = session[1].to_i
      end
      
      if subsession = href.match(/session=(\d+)/i)
        subsession = subsession[1].to_i
      end
      
      return nil unless number and session and subsession
      return nil unless number > 0 and session > 0 and subsession > 0
       
      return number, session, subsession
    else
      nil
    end
  end
  
  def self.url_for(number, session, subsession)
    "http://www.senate.gov/legislative/LIS/roll_call_votes/vote#{session}#{subsession}/vote_#{session}_#{subsession}_#{zero_prefix number}.xml"
  end
  
  def self.zero_prefix(number)
    if number < 10
      "0000#{number}"
    elsif number < 100
      "000#{number}"
    elsif number < 1000
      "00#{number}"
    elsif number < 10000
      "0#{number}"
    else
      number
    end
  end
  
  def self.required_for(doc)
    doc.at("majority_requirement").text
  end
  
  def self.votes_for(doc, legislators, missing_legislators)
    voter_ids = {}
    voters = {}
    
    doc.search("//members/member").each do |elem|
      vote = (elem / 'vote_cast').text
      lis_id = (elem / 'lis_member_id').text

      legislators[lis_id] ||= lookup_legislator elem
      
      if legislators[lis_id]
        voter = legislators[lis_id]
        bioguide_id = voter['bioguide_id']
        voter_ids[bioguide_id] = vote
        voters[bioguide_id] = {:vote => vote, :voter => voter}
      else
        missing_legislators << {:lis_id => lis_id, :member_full => elem.at("member_full").text, :number => doc.at("vote_number").text.to_i}
      end
    end
    
    [voter_ids, voters]
  end
  
  def self.lookup_legislator(element)
    last_name = element.at("last_name").text
    first_name = element.at("first_name").text
    party = element.at("party").text
    state = element.at("state").text
    
    party = "I" if party == "ID"
    
    results = Legislator.where :chamber => "senate", :last_name => last_name, :party => party, :state => state
    results.size == 1 ? Utils.legislator_for(results.first) : nil
  end
  
  def self.bill_id_for(doc, session)
    elem = doc.at 'document_name'
    if !(elem and elem.text.present?)
      elem = doc.at 'amendment_to_document_number'
    end
      
    if elem and elem.text.present?
      code = elem.text.strip.gsub(' ', '').gsub('.', '').downcase
      type = code.gsub /\d/, ''
      number = code.gsub type, ''
      
      type.gsub! "hconres", "hcres" # house uses H CON RES
      
      if ["hr", "hres", "hjres", "hcres", "s", "sres", "sjres", "scres"].include?(type)
        "#{type}#{number}-#{session}"
      else
        nil
      end
    else
      nil
    end
  end
  
  def self.create_bill(bill_id, doc)
    bill = Utils.bill_from bill_id
    bill.attributes = {:abbreviated => true}
    
    elem = doc.at 'amendment_to_document_short_title'
    if elem and elem.text.present?
      bill.attributes = {:short_title => elem.text.strip}
    else
      elem 
      if (elem = doc.at 'document_short_title') and elem.text.present?
        bill.attributes = {:short_title => elem.text.strip}
      end
      
      if (elem = doc.at 'document_title') and elem.text.present?
        bill.attributes = {:official_title => elem.text.strip}
      end
      
    end
    
    bill.save!
    
    bill
  end
  
  def self.amendment_id_for(doc, session)
    elem = doc.at 'amendment_number'
    if elem and elem.text.present?
      number = elem.text.gsub(/[^\d]/, '').to_i
      "s#{number}-#{session}"
    else
      nil
    end
  end
  
  def self.voted_at_for(doc)
    # make sure we're set to EST
    Time.zone = ActiveSupport::TimeZone.find_tzinfo "America/New_York"
    
    Utils.utc_parse doc.at("vote_date").text
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