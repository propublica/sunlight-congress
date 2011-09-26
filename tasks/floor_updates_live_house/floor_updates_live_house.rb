require 'open-uri'
require 'nokogiri'

class FloorUpdatesLiveHouse
  
  def self.run(options = {})
    count = 0
    failures = []
    
    url = get_xml_url options
    return unless url # a warning report will have been filed
    
    puts url
  end
  
  def self.get_xml_url(options)
    if options[:day]
      date = Time.parse(options[:day]).strftime("%Y%m%d")
      "http://clerk.house.gov/floorsummary/Download.aspx?file=#{date}.xml"
    else
      
      html = nil
      begin
        html = open "http://clerk.house.gov/floorsummary/floor.aspx"
      rescue Timeout::Error, Errno::ECONNRESET, Errno::ETIMEDOUT, Errno::ENETUNREACH
        Report.warning self, "Network error on fetching the floor log, can't go on."
        return nil
      end
      
      doc = Nokogiri::HTML html
      
      elem = doc.css("a.downloadLink").first
      unless elem
        Report.warning self, "Couldn't find download link, can't go on"
        return nil
      end
      
      url = elem['href']
      
      # in case they switch to absolute links
      if url =~ /^http\:\/\//
        url
      else
        "http://clerk.house.gov/floorsummary/#{url}"
      end
    end
  end
  
end