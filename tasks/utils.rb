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

end