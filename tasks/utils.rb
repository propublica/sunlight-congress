require 'nokogiri'
require 'curb'
require 'yajl'

module Utils

  # document is a hash,
  # collection is a mapping (e.g. 'bills'),
  # id is a string unique to the collection
  # bulk_container is an array, will use it to persist a batch for bulk indexing
  #
  # if given a bulk_size, will use it to determine when to batch and empty the container
  def self.es_batch!(collection, id, document, batcher, options = {})
    # disable batching by default
    options[:batch_size] ||= 1

    # batch the document
    batcher << [id, document]

    # if container's full, index them all
    if batcher.size >= options[:batch_size].to_i
      es_flush! collection, batcher
    end
  end

  # indexes a document immediately
  def self.es_store!(collection, id, document)
    Searchable.client.index index: Searchable.index, id: id, type: collection, body: document
  end

  # force a batch index of the container (useful to close out a batch)
  def self.es_flush!(collection, batcher)
    return if batcher.empty?

    puts "\n-- Batch indexing #{batcher.size} documents into '#{collection}' --\n\n"

    ops = batcher.map do |id, document|
      {index: {
        _index: Searchable.index,
        _type: collection,
        _id: id,
        data: document
      }}
    end

    Searchable.client.bulk body: ops

    batcher.clear # reset
  end

  def self.citations_for(document, text, destination, options)

    if File.exists?(destination) and options[:recite].blank?
      puts "\tUsing cached citation JSON" if options[:debug]
      body = File.read destination
      hash = MultiJson.load body
    else
      url = "http://#{Environment.config['citation']['hostname']}/citation/find"
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
    hash['results']['citations'].each do |result|
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
      Curl::Err::GotNothingError,
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
        curl.headers["User-Agent"] = "sunlight-congress-api / curl"
        curl.perform
      rescue Curl::Err::ConnectionFailedError, Curl::Err::PartialFileError,
        Curl::Err::RecvError, Timeout::Error, Curl::Err::HostResolutionError,
        Curl::Err::GotNothingError,
        Errno::ECONNRESET, Errno::ETIMEDOUT, Errno::ENETUNREACH, Errno::ECONNREFUSED
        puts "Error curling #{url}"
        nil
      else
        curl.body_str
      end

      # if the code was 404, don't save some html 404 page
      if curl.status.starts_with?("404")
        return nil
      end

      if body and options[:json]
        begin
          body = Yajl::Parser.parse(body)
        rescue Yajl::ParseError => exc
          return nil
        end
      end

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

  def self.utc_parse(timestamp)
    time = Time.zone.parse(timestamp)
    time ? time.utc : nil
  end

  # e.g. 2009 & 2010 -> 111th congress, 2011 & 2012 -> 112th congress
  def self.current_congress
    congress_for_year current_legislative_year
  end

  def self.congress_for_year(year)
    ((year.to_i + 1) / 2) - 894
  end

  # legislative year - consider Jan 1, Jan 2, and first half of Jan 3 to be last year
  def self.current_legislative_year(now = nil)
    now ||= Time.now
    now = now.in_time_zone # enforce EST

    year = now.year
    if now.month == 1
      if [1, 2].include?(now.day)
        year - 1
      elsif (now.day == 3) and (now.hour < 12)
        year - 1
      else
        year
      end
    else
      year
    end
  end

  # legislative (sub)session - 1 or 2, depending on current legislative year
  def self.legislative_session_for_year(year)
    session = year % 2
    session = 2 if session == 0
    session.to_s
  end

  # e.g. 111 -> [2009, 2010], 112 -> [2011, 2012]
  def self.years_for_congress(congress)
    first = ((congress + 894) * 2) - 1
    [first, first + 1]
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

  def self.constant_vote_keys
    ["Yea", "Nay", "Not Voting", "Present"]
  end

  def self.vote_breakdown_for(voters)
    breakdown = {total: {}, party: {}}

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

    # ensure that on impeachment votes, even if everyone votes one way, include a 0 for the other way
    if votes.include?("Guilty") or votes.include?("Not Guilty")
      votes = (votes + ["Guilty", "Not Guilty"]).uniq
    end

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

    # senate
    when /On the Amendment/i
      "amendment"

    # house
    when /^On Agreeing to the Amendment/i
      "amendment"

    # house
    when /^On Motion to Concur/i, /^On Motion to Suspend the Rules and (Agree|Concur|Pass)/i, /^Suspend (?:the )?Rules and (Agree|Concur)/i
      "passage"

    # house
    when /^On Agreeing to the Resolution/i, /^On Agreeing to the Concurrent Resolution/i, /^On Agreeing to the Conference Report/i
      "passage"

    # senate
    when /^On the Joint Resolution/i, /^On the Concurrent Resolution/i, /^On the Resolution/i, /^On the Conference Report/i
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

  def self.split_roll_id(roll_id)
    chamber = roll_id.gsub /[^a-z]/, ''
    chamber = {'s' => 'senate', 'h' => 'house'}[chamber.downcase]
    number = roll_id.match(/[a-z]+(\d+)-/)[1].to_i
    year = roll_id.match(/-(\d+)$/)[1].to_i

    [chamber, number, year]
  end

  # number, congress (strings)
  def self.nomination_fields_from(nomination_id)
    nomination_id.match(/PN([\d-]+)-(\d+)$/).to_a[1..-1]
  end

  def self.bill_fields_from(bill_id)
    type = bill_id.gsub /[^a-z]/, ''
    number = bill_id.match(/[a-z]+(\d+)-/)[1].to_i
    congress = bill_id.match(/-(\d+)$/)[1].to_i

    chamber = {'h' => 'house', 's' => 'senate'}[type.first.downcase]

    [type, number, congress, chamber]
  end

  def self.amendment_fields_from(amendment_id)
    type = amendment_id.gsub /[^a-z]/, ''
    number = amendment_id.match(/[a-z]+(\d+)-/)[1].to_i
    congress = amendment_id.match(/-(\d+)$/)[1].to_i

    chamber = {'h' => 'house', 's' => 'senate'}[type.first.downcase]

    [type, number, congress, chamber]
  end

  def self.format_bill_code(bill_type, number)
    {
      "hres" => "H. Res.",
      "hjres" => "H. Joint Res.",
      "hconres" => "H. Con. Res.",
      "hr" => "H.R.",
      "s" => "S.",
      "sres" => "S. Res.",
      "sjres" => "S. Joint Res.",
      "sconres" => "S. Con. Res."
    }[bill_type] + " #{number}"
  end

  # fetching

  def self.document_for(document, fields)
    attributes = document.attributes.dup
    allowed_keys = fields.map {|f| f.to_s}

    # add any parent fields of subfields to allowed_keys array
    fields.each do |field|
      allowed_keys << field.to_s.split(".")[0] if field.to_s["."]
    end
    allowed_keys = allowed_keys.uniq

    # for some reason, the 'sort' here causes more keys to get filtered out than without it
    # without the 'sort', it is broken. I do not know why.
    attributes.keys.sort.each do |key|
      attributes.delete(key) unless allowed_keys.include?(key)
    end

    attributes
  end

  def self.legislator_for(legislator)
    document_for legislator, Legislator.basic_fields
  end

  def self.amendment_for(amendment)
    if amendment.is_a?(Amendment)
      document_for amendment, Amendment.basic_fields
    else
      if amendment = Amendment.where(amendment_id: amendment).only(Amendment.basic_fields).first
        document_for amendment, Amendment.basic_fields
      else
        nil
      end
    end
  end

  def self.committee_for(committee)
    document_for committee, Committee.basic_fields
  end

  def self.nomination_for(nomination_id)
    if nomination = Nomination.where(nomination_id: nomination_id).first
      document_for nomination, Nomination.basic_fields
    end
  end

  # usually referenced in absence of an actual bill object
  def self.bill_for(bill_id)
    if bill_id.is_a?(Bill)
      document_for bill_id, Bill.basic_fields
    else
      if bill = Bill.where(bill_id: bill_id).only(Bill.basic_fields).first
        document_for bill, Bill.basic_fields
      else
        nil
      end
    end
  end

  def self.bill_ids_for(text, congress)
    matches = text.scan(/((S\.|H\.)(\s*J\.|\s?R\.|\s?Con\.|\s*)(\s*Res\.?)*\s*\d+)/i).map {|r| r.first}.compact
    matches = matches.map {|code| bill_code_to_id code, congress}
    matches.uniq
  end

  def self.bill_code_to_id(code, congress)
    "#{code.tr(" ", "").tr('.', '').downcase}-#{congress}"
  end

  # takes an upcoming_bill object and a bill_id, and updates the latest_upcoming list
  # Removes all elements from the list that match the source_type of the given upcoming item, adds this one.
  def self.update_bill_upcoming!(bill_id, upcoming_bill)
    if bill = Bill.where(bill_id: bill_id).first
      attrs = {}
      UpcomingBill.basic_fields.each do |field|
        attrs[field] = upcoming_bill[field] unless field == :bill_id
      end

      bill['upcoming'] = (bill['upcoming'] || []).dup << attrs
      bill.save!
    end
  end

  # flushes mentions of upcoming schedulings on /bills
  def self.flush_bill_upcoming!(source_type)
    Bill.where("upcoming.source_type" => source_type).each do |bill|
      bill['upcoming'] = (bill['upcoming'] || []).dup.select do |upcoming|
        upcoming['source_type'] != source_type
      end
      bill.save!
    end
  end

  # source is a path to a file to be uploaded to S3
  # destination is the location in S3 to back it up to
  def self.backup!(bucket, source, destination, options = {})
    s3cmd = Environment.config['s3']['s3cmd']
    s3cfg = Environment.config['s3']['s3cfg']

    location = Environment.config['backup'][bucket.to_s]
    if location !~ /^s3/
      location = "s3://#{location}"
    end

    # ensure no double slash
    location = location[0..-2] if location[-1..-1] == "/"
    destination = destination[1..-1] if destination[0..0] == "/"

    # remove slashes from end of paths
    source = source[0..-2] if source[-1..-1] == "/"
    destination = destination[0..-2] if destination[-1..-1] == "/"

    # sync means that source and destination are directories
    # if options[:sync]
    #   command = "#{s3cmd} --config=#{s3cfg} sync -P #{source}/ #{location}/#{destination}/"
    # otherwise, assume it's a single file, just put
    # else
      command = "#{s3cmd} --config=#{s3cfg} put -P \"#{source}\" \"#{location}/#{destination}\""
    # end

    if options[:silent]
      command << " > /dev/null"
    end

    system command
  end

end