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
  
  def self.vote_mapping
    {
      '-' => :nays, 
      '+' => :ayes, 
      '0' => :not_voting, 
      'P' => :present
    }
  end
  
  def self.vote_breakdown_for(voters)
    breakdown = {:total => {}}
    mapping = vote_mapping
    
    voters.each do|bioguide_id, voter|      
      party = voter[:voter]['party']
      vote = mapping[voter[:vote]] || voter[:vote]
      
      breakdown[party] ||= {}
      breakdown[party][vote] ||= 0
      breakdown[:total][vote] ||= 0
      
      breakdown[party][vote] += 1
      breakdown[:total][vote] += 1
    end
    
    parties = breakdown.keys
    votes = (breakdown[:total].keys + mapping.values).uniq
    votes.each do |vote|
      parties.each do |party|
        breakdown[party][vote] ||= 0
      end
    end
    
    breakdown
  end

end