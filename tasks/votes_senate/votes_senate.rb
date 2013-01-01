 'nokogiri'

class VotesSenate

  # Syncs vote data with the House of Representatives.
  # 
  # By default, looks through the Clerk's EVS pages, and 
  # re/downloads data for the last 10 roll call votes.
  # 
  # Options can be passed in to archive whole years, which can ignore 
  # already downloaded files (to support resuming).
  # 
  # options:
  #   force: if archiving, force it to re-download existing files.
  #   year: archive an entire year of data (defaults to latest 20)
  #   number: only download a specific roll call vote number for the given year. Ignores other options, except for year. 
  #   limit: only download a certain number of votes (stop short, useful for testing/development)
  #   skip_text: don't search index related text
  
  def self.run(options = {})
    year = if options[:year].nil? or (options[:year] == 'current')
      Time.now.year
    else
      options[:year].to_i
    end
    
    initialize_disk! year

    to_get = []

    if options[:number]
      to_get = [options[:number].to_i]
    else
      # count down from the top
      unless latest_roll = latest_roll_for(year, options)
        Report.failure self, "Failed to find the latest new roll on the Senate's site, can't go on."
        return
      end
      
      if options[:year]
        from_roll = 1
      else
        latest = options[:latest] ? options[:latest].to_i : 20
        from_roll = (latest_roll - latest) + 1
        from_roll = 1 if from_roll < 1
      end

      to_get = (from_roll..latest_roll).to_a.reverse
      
      if options[:limit]
        to_get = to_get.first options[:limit].to_i
      end
    end

    count = 0

    download_failures = []
    es_failures = []
    missing_legislators = []
    missing_bill_ids = []
    # missing_amendment_ids = []

    batcher = [] # ES batch indexer

    # will be referenced by LIS ID as a cache built up as we parse through votes
    legislators = {}

    congress = options[:congress] || Utils.congress_for_year(year)

    to_get.each do |number|
      roll_id = "s#{number}-#{year}"

      puts "[#{roll_id}] Syncing to disc..." if options[:debug]
      unless download_roll year, number, download_failures, options
        puts "[#{roll_id}] WARNING: Couldn't sync to disc, skipping"
        next
      end
      
      doc = Nokogiri::XML open(destination_for(year, number))
      puts "[#{roll_id}] Saving vote information..." if options[:debug]
      

      bill_id = bill_id_for doc, congress
      amendment_id = amendment_id_for doc, congress
      voter_ids, voters = votes_for doc, legislators, missing_legislators

      roll_type = doc.at("question").text
      question = doc.at("vote_question_text").text
      result = doc.at("vote_result").text

      vote = Vote.find_or_initialize_by roll_id: roll_id
      vote.attributes = {
        vote_type: Utils.vote_type_for(roll_type, question),
        chamber: "senate",
        year: year,
        number: number,
        
        congress: congress,
        
        roll_type: roll_type,
        question: question,
        result: result,
        required: required_for(doc),
        
        voted_at: voted_at_for(doc),
        voter_ids: voter_ids,
        voters: voters,
        breakdown: Utils.vote_breakdown_for(voters),
      }
      
      if bill_id
        if bill = Utils.bill_for(bill_id)
          vote.attributes = {
            bill_id: bill_id,
            bill: bill
          }
        else
          missing_bill_ids << {roll_id: roll_id, bill_id: bill_id}
        end
      end
      
      # for now, only bother with amendments on bills
      # if bill_id and amendment_id
      #   if amendment = Amendment.where(:amendment_id => amendment_id).only(Amendment.basic_fields).first
      #     vote.attributes = {
      #       :amendment_id => amendment_id,
      #       :amendment => Utils.amendment_for(amendment)
      #     }
      #   else
      #     missing_amendment_ids << {:roll_id => roll_id, :amendment_id => amendment_id}
      #   end
      # end
      
      vote.save!

      # replicate it in ElasticSearch
      unless options[:skip_text]
        puts "[#{roll_id}] Indexing vote into ElasticSearch..." if options[:debug]
        Utils.search_index_vote! roll_id, vote.attributes, batcher, options
      end

      count += 1
    end

    # index any leftover docs
    Utils.es_flush! 'votes', batcher

    if download_failures.any?
      Report.warning self, "Failed to download #{download_failures.size} files while syncing against the House Clerk votes collection for #{year}", download_failures: download_failures
    end

    if missing_legislators.any?
      Report.warning self, "Couldn't look up #{missing_legislators.size} legislators in Senate roll call listing. Vote counts on roll calls may be inaccurate until these are fixed.", missing_legislators: missing_legislators
    end
    
    if missing_bill_ids.any?
      Report.warning self, "Found #{missing_bill_ids.size} missing bill_id's while processing votes.", missing_bill_ids: missing_bill_ids
    end
    
    # if missing_amendment_ids.any?
    #   Report.warning self, "Found #{missing_amendment_ids.size} missing amendment_id's while processing votes.", missing_amendment_ids: missing_amendment_ids
    # end

    Report.success self, "Successfully synced #{count} Senate roll call votes for #{year}"
  end

  def self.initialize_disk!(year)
    FileUtils.mkdir_p "data/senate/rolls/#{year}"
  end

  def self.destination_for(year, number)
    "data/senate/rolls/#{year}/#{zero_prefix number}.xml"
  end
  
  
  # find the latest roll call number listed on the Senate roll call vote page for a given year
  def self.latest_roll_for(year, options = {})
    session = options[:session] || {0 => 2, 1 => 1}[year % 2]
    congress = options[:congress] || Utils.congress_for_year(year)
    url = "http://www.senate.gov/legislative/LIS/roll_call_lists/vote_menu_#{congress}_#{session}.htm"
    
    puts "[#{year}] Fetching index page for #{year} (#{url}) from Senate website..." if options[:debug]
    return nil unless doc = Utils.html_for(url)
    
    element = doc.css("td.contenttext td.contenttext a").first
    return nil unless element and element.text.present?
    number = element.text.to_i
    number > 0 ? number : nil
  end
  
  def self.url_for(year, number, options = {})
    session = options[:session] || {0 => 2, 1 => 1}[year % 2]
    congress = options[:congress] || Utils.congress_for_year(year)
    "http://www.senate.gov/legislative/LIS/roll_call_votes/vote#{congress}#{session}/vote_#{congress}_#{session}_#{zero_prefix number}.xml"
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

      legislators[lis_id] ||= lookup_legislator lis_id, elem
      
      if legislators[lis_id]
        voter = legislators[lis_id]
        bioguide_id = voter['bioguide_id']
        voter_ids[bioguide_id] = vote
        voters[bioguide_id] = {vote: vote, voter: voter}
      else
        missing_legislators << {lis_id: lis_id, member_full: elem.at("member_full").text, number: doc.at("vote_number").text.to_i}
      end
    end
    
    [voter_ids, voters]
  end
  
  def self.lookup_legislator(lis_id, element)
    legislator = Legislator.where(lis_id: lis_id).first
    legislator ? Utils.legislator_for(legislator) : nil
  end
  
  def self.bill_id_for(doc, congress)
    elem = doc.at 'document_name'
    if !(elem and elem.text.present?)
      elem = doc.at 'amendment_to_document_number'
    end
      
    if elem and elem.text.present?
      code = elem.text.strip.gsub(' ', '').gsub('.', '').downcase
      type = code.gsub /\d/, ''
      number = code.gsub type, ''
      
      if ["hr", "hres", "hjres", "hconres", "s", "sres", "sjres", "sconres"].include?(type)
        "#{type}#{number}-#{congress}"
      else
        nil
      end
    else
      nil
    end
  end
  
  def self.amendment_id_for(doc, congress)
    elem = doc.at 'amendment_number'
    if elem and elem.text.present?
      number = elem.text.gsub(/[^\d]/, '').to_i
      "s#{number}-#{congress}"
    else
      nil
    end
  end
  
  def self.voted_at_for(doc)
    Utils.utc_parse doc.at("vote_date").text
  end

  def self.download_roll(year, number, failures, options = {})
    url = url_for year, number, options
    destination = destination_for year, number

    # cache aggressively, redownload only if force option is passed
    if File.exists?(destination) and options[:force].blank?
      puts "\tCached at #{destination}" if options[:debug]
      return true
    end

    puts "\tDownloading #{url} to #{destination}" if options[:debug]

    unless curl = Utils.curl(url, destination)
      failures << {message: "Couldn't download", url: url, destination: destination}
      return false
    end
      
    unless curl.content_type == "application/xml"
      # don't consider it a failure - the vote's probably just not up yet
      # failures << {message: "Wrong content type", url: url, destination: destination, content_type: curl.content_type}
      FileUtils.rm destination # delete bad file from the cache
      return false
    end

    # sanity check on files less than expected - 
    # most are ~23K, so if something is less than 20K, check the XML for malformed errors
    if curl.downloaded_content_length < 20000
      # retry once, quick check
      puts "\tRe-downloading once, looked truncated" if options[:debug]
      curl = Utils.curl(url, destination)
      
      if curl.downloaded_content_length < 20000
        begin
          Nokogiri::XML(open(destination)) {|config| config.strict}
        rescue
          puts "\tFailed strict XML check, assuming it's still truncated" if options[:debug]
          failures << {message: "Failed check", url: url, destination: destination, content_length: curl.downloaded_content_length}
          FileUtils.rm destination
          return false
        else
          puts "\tOK, passes strict XML check, accepting it" if options[:debug]
        end
      end
    end

    true
  end
  
end

# Shorten timeout in Net::HTTP
require 'net/http'
module Net
  class HTTP
    alias old_initialize initialize

    def initialize(*args)
      old_initialize(*args)
      @read_timeout = 8 # 8 seconds
    end
  end
end