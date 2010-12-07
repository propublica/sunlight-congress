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
  
  def self.voter_fields
    [:first_name, :nickname, :last_name, :name_suffix, :title, :state, :party, :chamber, :district, :govtrack_id, :bioguide_id]
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
    
    # initialize
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
  def self.vote_type_for(roll_type)
    case roll_type
    
    # senate only
    when /cloture/i 
      "cloture"
      
    # senate only
    when /^On the Nomination$/i
      "nomination"
      
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

end