require 'nokogiri'
require 'curb'
require 'httparty'
require 'yajl'

module Utils

  # document is a hash, 
  # collection is a mapping (e.g. 'bills'), 
  # id is a string unique to the collection
  # bulk_container is an array, will use it to persist a batch for bulk indexing
  # 
  # if given a bulk_size, will use it to determine when to batch and empty the container
  def self.es_batch!(collection, id, document, batcher, options = {})
    # default to batching 100
    options[:batch_size] ||= 100

    # batch the document
    batcher << [id, document]

    # if container's full, index them all
    if batcher.size >= options[:batch_size].to_i
      es_flush! collection, batcher
    end
  end

  # indexes a document immediately
  def self.es_store!(collection, id, document)
    Searchable.client.index document, id: id, type: collection
  end

  # force a batch index of the container (useful to close out a batch)
  def self.es_flush!(collection, batcher)
    return if batcher.empty? 

    puts "\n-- Batch indexing #{batcher.size} documents into '#{collection}' --\n\n"

    Searchable.client.bulk do |client|
      batcher.each do |id, document|
        client.index document, id: id, type: collection
      end
    end

    batcher.clear # reset
  end

  def self.citations_for(document, text, destination, options)

    if File.exists?(destination) and options[:recite].blank?
      puts "\tUsing cached citation JSON" if options[:debug]
      body = File.read destination
      hash = MultiJson.load body
    else
      url = "http://#{Api.config['citation']['hostname']}/citation/find.json"
      puts "\tExtracting citations..." if options[:debug]
      curl = Curl.post url, 
        text: CGI.escape(text), 
        "options[excerpt]" => (options[:cite_excerpt] || 250),
        "options[types]" => "usc,law",
        "options[parents]" => "true"
      body = curl.body_str
      hash = MultiJson.load body
      Utils.write destination, JSON.pretty_generate(hash)
    end

    puts body if ENV['cite_debug'].present?
    

    # index citations by ID: assumes they are unique even across types
    citations = {}
    hash['results'].each do |result|
      id = result[result['type']]['id']
      citations[id] ||= []
      citations[id] << result
    end

    # document's unique key as defined in model
    document_id = document[document.class.cite_key.to_s]
    
    # clear existing citations for this document
    Citation.where(document_id: document_id).delete_all

    citations.each do |citation_id, matches|
      citation = Citation.find_or_initialize_by(
        document_id: document_id,
        document_type: document.class.to_s,
        citation_id: citation_id
      )
      citation.citations = matches
      citation.save!
    end

    puts "Extracted citations from #{document_id}: #{citations.keys.inspect}" if options[:debug]

    citations.keys

  rescue Curl::Err::ConnectionFailedError, Curl::Err::PartialFileError, 
    Curl::Err::RecvError, Curl::Err::HostResolutionError,
    Timeout::Error, Errno::ECONNRESET, Errno::ETIMEDOUT, 
    Errno::ENETUNREACH, Errno::ECONNREFUSED => ex
    puts "Error connecting to citation API"
    nil
  rescue Curl::Err::GotNothingError => ex
    puts "Crashed citation API! Waiting 5 seconds..."
    sleep 5 # wait for it to come back up
    nil
  rescue MultiJson::DecodeError => ex
    puts "Got bad response back from citation API"
    nil
  end

  def self.curl(url, destination = nil)
    body = begin
      curl = Curl::Easy.new url
      curl.follow_location = true # follow redirects
      curl.perform
    rescue Curl::Err::ConnectionFailedError, Curl::Err::PartialFileError, 
      Curl::Err::RecvError, Timeout::Error, Curl::Err::HostResolutionError, 
      Errno::ECONNRESET, Errno::ETIMEDOUT, Errno::ENETUNREACH, Errno::ECONNREFUSED
      puts "Error curling #{url}"
      nil
    else
      curl.body_str
    end

    # returns true or false if a destination is given
    if destination
      return nil unless body
      write destination, body
      curl

    # otherwise, returns the body of the response
    else
      body
    end
    
  end

  # general helper for downloading stuff and caching
  # 
  # options:
  #   cache: use cache; will always download from network if missing
  #   destination: destination on disk, required for caching
  #   debug: output info to STDOUT
  #   json: if true, returns parsed content, and caches it to disk in pretty (indented) form
  #   rate_limit: number of seconds to sleep after each download (can be a decimal)
  def self.download(url, options = {})

    # cache if caching is opted-into, and the cache exists
    if options[:cache] and options[:destination] and File.exists?(options[:destination])
      puts "Cached #{url} from #{options[:destination]}, not downloading..." if options[:debug]
      
      body = File.read options[:destination]
      body = Yajl::Parser.parse(body) if options[:json]
      body

    # download, potentially saving to disk
    else
      puts "Downloading #{url} to #{options[:destination] || "[not cached]"}..." if options[:debug]
      
      body = begin
        curl = Curl::Easy.new url
        curl.follow_location = true # follow redirects
        curl.perform
      rescue Curl::Err::ConnectionFailedError, Curl::Err::PartialFileError, 
        Curl::Err::RecvError, Timeout::Error, Curl::Err::HostResolutionError, 
        Errno::ECONNRESET, Errno::ETIMEDOUT, Errno::ENETUNREACH, Errno::ECONNREFUSED
        puts "Error curling #{url}"
        nil
      else
        curl.body_str
      end

      body = Yajl::Parser.parse(body) if options[:json]

      # returns true or false if a destination is given
      if options[:destination]
        return nil unless body

        if options[:json] # body will be parsed
          write options[:destination], JSON.pretty_generate(body)
        else
          write options[:destination], body
        end
      end

      if options[:rate_limit]
        sleep options[:rate_limit].to_f
      end
      
      body
    end
  end

  def self.write(destination, content)
    FileUtils.mkdir_p File.dirname(destination)
    File.open(destination, 'w') {|f| f.write content}
  end

  def self.html_for(url)
    body = curl url
    body ? Nokogiri::HTML(body) : nil
  end

  def self.xml_for(url)
    body = curl url
    body ? Nokogiri::XML(body) : nil
  end
  
  # If it's a full timestamp with hours and minutes and everything, store that
  # Otherwise, if it's just a day, store the day with a date of noon UTC
  # So that it's the same date everywhere
  def self.ensure_utc(timestamp)
    if timestamp =~ /:/
      Time.xmlschema timestamp
    else
      noon_utc_for timestamp
    end
  end
  
  # given a timestamp of the form "2011-02-18", return noon UTC on that day
  def self.noon_utc_for(timestamp)
    time = timestamp.is_a?(String) ? Time.parse(timestamp) : timestamp
    time.getutc + (12-time.getutc.hour).hours
  end

  def self.utc_parse(timestamp)
    time = Time.zone.parse(timestamp)
    time ? time.utc : nil
  end
  
  # e.g. 2009 & 2010 -> 111th session, 2011 & 2012 -> 112th session
  def self.current_session
    session_for_year Time.now.year
  end
  
  def self.session_for_year(year)
    ((year + 1) / 2) - 894
  end
  
  # map govtrack type to RTC type
  def self.bill_type_for(govtrack_type)
    {
      :h => 'hr',
      :hr => 'hres',
      :hj => 'hjres',
      :hc => 'hcres',
      :s => 's',
      :sr => 'sres',
      :sj => 'sjres',
      :sc => 'scres'
    }[govtrack_type.to_sym]
  end
  
  def self.gpo_type_for(bill_type)
    {
      'hr' => 'hr',
      'hres' => 'hres',
      'hjres' => 'hjres',
      'hcres' => 'hconres',
      's' => 's',
      'sres' => 'sres',
      'sjres' => 'sjres',
      'scres' => 'sconres'
    }[bill_type.to_s]
  end
  
  # adapted from http://www.gpoaccess.gov/bills/glossary.html
  def self.bill_version_name_for(version_code)
    {
      'ash' => "Additional Sponsors House",
      'ath' => "Agreed to House",
      'ats' => "Agreed to Senate",
      'cdh' => "Committee Discharged House",
      'cds' => "Committee Discharged Senate",
      'cph' => "Considered and Passed House",
      'cps' => "Considered and Passed Senate",
      'eah' => "Engrossed Amendment House",
      'eas' => "Engrossed Amendment Senate",
      'eh' => "Engrossed in House",
      'ehr' => "Engrossed in House-Reprint",
      'eh_s' => "Engrossed in House (No.) Star Print [*]",
      'enr' => "Enrolled Bill",
      'es' => "Engrossed in Senate",
      'esr' => "Engrossed in Senate-Reprint",
      'es_s' => "Engrossed in Senate (No.) Star Print",
      'fah' => "Failed Amendment House",
      'fps' => "Failed Passage Senate",
      'hdh' => "Held at Desk House",
      'hds' => "Held at Desk Senate",
      'ih' => "Introduced in House",
      'ihr' => "Introduced in House-Reprint",
      'ih_s' => "Introduced in House (No.) Star Print",
      'iph' => "Indefinitely Postponed in House",
      'ips' => "Indefinitely Postponed in Senate",
      'is' => "Introduced in Senate",
      'isr' => "Introduced in Senate-Reprint",
      'is_s' => "Introduced in Senate (No.) Star Print",
      'lth' => "Laid on Table in House",
      'lts' => "Laid on Table in Senate",
      'oph' => "Ordered to be Printed House",
      'ops' => "Ordered to be Printed Senate",
      'pch' => "Placed on Calendar House",
      'pcs' => "Placed on Calendar Senate",
      'pp' => "Public Print",
      'rah' => "Referred w/Amendments House",
      'ras' => "Referred w/Amendments Senate",
      'rch' => "Reference Change House",
      'rcs' => "Reference Change Senate",
      'rdh' => "Received in House",
      'rds' => "Received in Senate",
      're' => "Reprint of an Amendment",
      'reah' => "Re-engrossed Amendment House",
      'renr' => "Re-enrolled",
      'res' => "Re-engrossed Amendment Senate",
      'rfh' => "Referred in House",
      'rfhr' => "Referred in House-Reprint",
      'rfh_s' => "Referred in House (No.) Star Print",
      'rfs' => "Referred in Senate",
      'rfsr' => "Referred in Senate-Reprint",
      'rfs_s' => "Referred in Senate (No.) Star Print",
      'rh' => "Reported in House",
      'rhr' => "Reported in House-Reprint",
      'rh_s' => "Reported in House (No.) Star Print",
      'rih' => "Referral Instructions House",
      'ris' => "Referral Instructions Senate",
      'rs' => "Reported in Senate",
      'rsr' => "Reported in Senate-Reprint",
      'rs_s' => "Reported in Senate (No.) Star Print",
      'rth' => "Referred to Committee House",
      'rts' => "Referred to Committee Senate",
      'sas' => "Additional Sponsors Senate",
      'sc' => "Sponsor Change House",
      's_p' => "Star (No.) Print of an Amendment"
    }[version_code]
  end
  
  def self.constant_vote_keys
    ["Yea", "Nay", "Not Voting", "Present"]
  end
  
  def self.vote_breakdown_for(voters)
    breakdown = {:total => {}, :party => {}}
    
    voters.each do|bioguide_id, voter|      
      party = voter[:voter]['party']
      vote = voter[:vote]
      
      breakdown[:party][party] ||= {}
      breakdown[:party][party][vote] ||= 0
      breakdown[:total][vote] ||= 0
      
      breakdown[:party][party][vote] += 1
      breakdown[:total][vote] += 1
    end
    
    parties = breakdown[:party].keys
    votes = (breakdown[:total].keys + constant_vote_keys).uniq
    votes.each do |vote|
      breakdown[:total][vote] ||= 0
      parties.each do |party|
        breakdown[:party][party][vote] ||= 0
      end
    end
    
    breakdown
  end
  
  
  # Used when processing roll call votes the first time.
  # "passage" will also reliably get set in the second half of votes_archive,
  # when it goes back over each bill and looks at its passage votes.
  def self.vote_type_for(roll_type, question)
    case roll_type
    
    # senate only
    when /cloture/i 
      "cloture"
      
    # senate only
    when /^On the Nomination$/i
      "nomination"
    
    when /^Guilty or Not Guilty/i
      "impeachment"
    
    when /^On the Resolution of Ratification/i
      "treaty"
    
    when /^On (?:the )?Motion to Recommit/i
      "recommit"
      
    # common
    when /^On Passage/i
      "passage"
      
    # house
    when /^On Motion to Concur/i, /^On Motion to Suspend the Rules and (Agree|Concur|Pass)/i, /^Suspend (?:the )?Rules and (Agree|Concur)/i,
      "passage"
    
    # house
    when /^On Agreeing to the Resolution/i, /^On Agreeing to the Concurrent Resolution/i, /^On Agreeing to the Conference Report/i
      "passage"
      
    # senate
    when /^On the Joint Resolution/i, /^On the Concurrent Resolution/i, /^On the Resolution/i
      "passage"
    
    # house only
    when /^Call of the House$/i
      "quorum"
    
    # house only
    when /^Election of the Speaker$/i
      "leadership"
    
    # various procedural things (and various unstandardized vote desc's that will fall through the cracks)
    else
      "other"
      
    end
  end
  
  def self.bill_from(bill_id)
    type, number, session, code, chamber = bill_fields_from bill_id
    
    bill = Bill.new :bill_id => bill_id
    bill.attributes = {
      bill_type: type,
      number: number,
      session: session,
      code: code,
      chamber: chamber
    }
    
    bill
  end
  
  def self.bill_fields_from(bill_id)
    type = bill_id.gsub /[^a-z]/, ''
    number = bill_id.match(/[a-z]+(\d+)-/)[1].to_i
    session = bill_id.match(/-(\d+)$/)[1].to_i
    
    code = "#{type}#{number}"
    chamber = {'h' => 'house', 's' => 'senate'}[type.first.downcase]
    
    [type, number, session, code, chamber]
  end
  
  def self.amendment_from(amendment_id)
    chamber = {'h' => 'house', 's' => 'senate'}[amendment_id.gsub(/[^a-z]/, '')]
    number = amendment_id.match(/[a-z]+(\d+)-/)[1].to_i
    session = amendment_id.match(/-(\d+)$/)[1].to_i
    
    amendment = Amendment.new :amendment_id => amendment_id
    amendment.attributes = {
      :chamber => chamber,
      :number => number,
      :session => session
    }
    
    amendment
  end
  
  def self.format_bill_code(bill_type, number)
    {
      "hres" => "H. Res.",
      "hjres" => "H. Joint Res.",
      "hcres" => "H. Con. Res.",
      "hr" => "H.R.",
      "s" => "S.",
      "sres" => "S. Res.",
      "sjres" => "S. Joint Res.",
      "scres" => "S. Con. Res."
    }[bill_type] + " #{number}"
  end
  
  # fetching
  
  def self.document_for(document, fields)
    attributes = document.attributes.dup
    allowed_keys = fields.map {|f| f.to_s}
    
    # for some reason, the 'sort' here causes more keys to get filtered out than without it
    # without the 'sort', it is broken. I do not know why.
    attributes.keys.sort.each {|key| attributes.delete(key) unless allowed_keys.include?(key)}
    
    attributes
  end
  
  def self.legislator_for(legislator)
    document_for legislator, Legislator.basic_fields
  end
  
  def self.amendment_for(amendment)
    document_for amendment, Amendment.basic_fields
  end
  
  def self.committee_for(committee)
    document_for committee, Committee.basic_fields
  end
  
  # usually referenced in absence of an actual bill object
  def self.bill_for(bill_id)
    if bill_id.is_a?(Bill)
      document_for bill_id, Bill.basic_fields
    else
      if bill = Bill.where(:bill_id => bill_id).only(Bill.basic_fields).first
        document_for bill, Bill.basic_fields
      else
        nil
      end
    end
  end
  
  def self.bill_ids_for(text, session)
    matches = text.scan(/((S\.|H\.)(\s?J\.|\s?R\.|\s?Con\.| ?)(\s?Res\.?)*\s?\d+)/i).map {|r| r.first}.uniq.compact
    matches = matches.map {|code| bill_code_to_id code, session}
    matches.uniq
  end
    
  def self.bill_code_to_id(code, session)
    "#{code.gsub(/con/i, "c").tr(" ", "").tr('.', '').downcase}-#{session}"
  end

  # takes an upcoming_bill object and a bill_id, and updates the latest_upcoming list
  # Removes all elements from the list that match the source_type of the given upcoming item, adds this one.
  def self.update_bill_upcoming!(bill_id, upcoming_bill)
    if bill = Bill.where(:bill_id => bill_id).first
      old_latest_upcoming = (bill['latest_upcoming'] || []).dup
      new_latest_upcoming = old_latest_upcoming.select do |upcoming|
        upcoming['source_type'] != upcoming_bill[:source_type]
      end

      # remove bill and bill_id sections from upcoming bill object
      attrs = upcoming_bill.attributes.dup
      ['bill', 'bill_id', '_id', 'created_at', 'updated_at'].each do |attr|
        attrs.delete attr
      end

      new_latest_upcoming << attrs
      bill[:latest_upcoming] = new_latest_upcoming
      bill.save!
    end
  end

  # takes an attribute hash that belongs to a vote, and indexes it in ElasticSearch by the given ID
  # will look up an associated bill by ID and will grab its searchable fields as appropriate
  def self.search_index_vote!(vote_id, attributes, batcher, options = {})
    attributes.delete '_id'

    attributes.delete 'voters'
    attributes.delete 'voter_ids'

    if bill_id = attributes['bill_id']
      if bill = Bill.where(:bill_id => bill_id).first
        attributes['bill'] = Utils.bill_for(bill).merge(
          :summary => bill['summary'],
          :keywords => bill['keywords']
        )
        if bill['last_version']
          if bill_version = BillVersion.where(:bill_version_id => bill['last_version']['bill_version_id']).only(:full_text).first
            attributes['bill']['last_version_text'] = bill_version['full_text']
          end
        end
      end
    end

    if amendment_id = attributes['amendment_id']
      if amendment = Amendment.where(:amendment_id => amendment_id).first
        attributes['amendment'] = Utils.amendment_for(amendment)
      end
    end

    es_batch! 'votes', vote_id, attributes, batcher, options
  end

  # transmutes hash of voter_ids as it appears in the mongo endpoint, 
  # into something compact for search indexing - a performance sacrifice
  def self.search_voter_ids(voter_ids)
    new_ids = {}
    voter_ids.each do |id, vote|
      new_ids[vote] ||= []
      new_ids[vote] << id
    end
    new_ids
  end

  # should work for both daily and weekly house notices
  # http://majorityleader.gov/floor/daily.html
  # http://majorityleader.gov/floor/weekly.html
  #
  # If the PDF link is valid, and has a date in it, then use that date, and use it as the permalink
  # If not, extract the date from the header, and use the original url as the permalink
  def self.permalink_and_date_from_house_gop_whip_notice(url, doc)
    date = nil
    permalink = url # default to the HTML page, unless we can get a valid PDF out of this

    # first preference is to get the date from the PDF URL
    links = (doc / :a).select {|x| x.text =~ /printable pdf/i}
    a = links.first

    date_results = nil

    if a
      pdf_url = a['href']
      date_results = pdf_url.scan(/\/([^\/]+)\.pdf$/i)
    end
    
    if date_results and date_results.any? and date_results.first.any?
      date_str = date_results.first.first
      month, day, year = date_str.split "-"
      date = noon_utc_for Time.local(year, month, day)
      permalink = pdf_url

    # but if the PDF URL is messed up, try to get it from the header
    else
      begin
        date = Date.parse doc.css("#news_text").first.css("b").first.text
        date = noon_utc_for date.to_time
      rescue ArgumentError
        date = nil
      end
    end

    [permalink, date]
  end
end