module Utils
  
  # If it's a full timestamp with hours and minutes and everything, store that
  # Otherwise, if it's just a day, store the day with a date of noon UTC
  # So that it's the same date everywhere
  def self.govtrack_time_for(timestamp)
    if timestamp =~ /:/
      Time.xmlschema timestamp
    else
      time = Time.parse timestamp
      time.getutc + (12-time.getutc.hour).hours
    end
  end
  
  # e.g. 2009 & 2010 -> 111th session, 2011 & 2012 -> 112th session
  def self.current_session
    ((Time.now.year + 1) / 2) - 894
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
  
  # map RTC type to GovTrack type
  def self.govtrack_type_for(bill_type)
    {
      'hr' => 'h',
      'hres' => 'hr',
      'hjres' => 'hj',
      'hcres' => 'hc',
      's' => 's',
      'sres' => 'sr',
      'sjres' => 'sj',
      'scres' => 'sc'
    }[bill_type.to_s]
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
      :bill_type => type,
      :number => number,
      :session => session,
      :code => code,
      :chamber => chamber
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
  
  # basic fields and common fetching of them for redundant data
  
  def self.legislator_fields
    [
      :govtrack_id, :bioguide_id,
      :title, :first_name, :nickname, :last_name, :name_suffix, 
      :state, :party, :chamber, :district
    ]
  end
  
  def self.bill_fields
    Bill.basic_fields
  end
  
  def self.amendment_fields
    Amendment.basic_fields
  end
  
  def self.committee_fields
    [:name, :chamber, :committee_id]
  end
  
  def self.document_for(document, fields)
    attributes = document.attributes.dup
    allowed_keys = fields.map {|f| f.to_s}
    attributes.keys.each {|key| attributes.delete key unless allowed_keys.include?(key)}
    attributes
  end
  
  def self.legislator_for(legislator)
    document_for legislator, legislator_fields
  end
  
  def self.amendment_for(amendment)
    document_for amendment, amendment_fields
  end
  
  def self.committee_for(committee)
    document_for committee, committee_fields
  end
  
  # usually referenced in absence of an actual bill object
  def self.bill_for(bill_id)
    if bill_id.is_a?(Bill)
      document_for bill_id, bill_fields
    else
      if bill = Bill.where(:bill_id => bill_id).only(bill_fields).first
        document_for bill, bill_fields
      else
        nil
      end
    end
  end
  
  # known discrepancies between us and GovTrack
  def self.committee_id_for(govtrack_id)
    govtrack_id
  end
end