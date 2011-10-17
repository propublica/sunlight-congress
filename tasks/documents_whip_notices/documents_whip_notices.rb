require 'open-uri'
require 'nokogiri'
require 'feedzirra'

class DocumentsWhipNotices
  
  HOUSE_DEM_URL = 'http://www.democraticwhip.gov/rss/%s/all'
  HOUSE_REP_URL = 'http://www.majorityleader.house.gov/floor/%s.html'
  
  def self.run(options = {})
    total_count = 0
    
    unless options[:party] == 'r'
      total_count += house_dem 'daily', HOUSE_DEM_URL % 32
      total_count += house_dem 'nightly', HOUSE_DEM_URL % 34
      total_count += house_dem 'weekly', HOUSE_DEM_URL % 31
    end
    
    unless options[:party] == 'd'
      total_count += house_rep 'daily', HOUSE_REP_URL % "daily"
      total_count += house_rep 'weekly', HOUSE_REP_URL % "weekly"
    end
    
    Report.success self, "Updated or created #{total_count} whip notices"
  end
  
  def self.house_dem(type, url)
    rss = nil
    begin
      rss = Feedzirra::Feed.fetch_and_parse url
    rescue
      Report.warning self, "Network error on fetching House Democratic #{type} whip notice, can't go on.", :url => url
      return
    end
    
    count = 0
    
    rss.entries.each do |entry|
      notice_url = entry.url
      posted_at = entry.published
      title = entry.title
      for_date = Time.parse entry.title
      session = Utils.session_for_year for_date.year
    
      notice = Document.find_or_initialize_by(
        :document_type => "whip_notice",
        :chamber => "house",
        :for_date => for_date.strftime("%Y-%m-%d"),
        :party => 'D', 
        :notice_type => type
      )
      
      notice.attributes = {
        :posted_at => posted_at,
        :url => notice_url,
        :session => session,
        :title => title
      }
      
      notice.save!
      
      count += 1
    end
    
    count
  end
  
  def self.house_rep(type, url)
    unless html = content_for(url)
      Report.warning self, "Network error on fetching House Republican #{type} whip notice, can't go on.", :url => url
      return
    end
    
    doc = Nokogiri::HTML html
    
    links = (doc / :a).select {|x| x.text =~ /printable pdf/i}
    a = links.first
    pdf_url = a['href']
    date_results = pdf_url.scan(/\/([^\/]+)\.pdf$/i)
    
    unless date_results.any? and date_results.first.any?
      Report.warning self, "Couldn't find PDF date in Republican whip #{type} notice page, can't go on", :url => url
      return
    end
    
    date_str = date_results.first.first
    month, day, year = date_str.split "-"
    
    posted_at = Utils.noon_utc_for Time.local(year, month, day)
    for_date = posted_at.strftime("%Y-%m-%d")
    session = Utils.session_for_year posted_at.year
    
    title = {
      "daily" => "Leader's Daily Schedule",
      "weekly" => "Leader's Weekly Schedule"
    }[type]
    
    notice = Document.find_or_initialize_by(
      :document_type => "whip_notice",
      :chamber => "house",
      :for_date => for_date,
      :party => "R",
      :notice_type => type
    )
    
    notice.attributes = {
      :posted_at => posted_at,
      :url => pdf_url,
      :session => session,
      :title => title
    }
    
    notice.save!
            
    1
  end
  def self.content_for(url)
    begin
      open(url).read
    rescue Timeout::Error, Errno::ECONNRESET, Errno::ETIMEDOUT, Errno::ENETUNREACH
      nil
    end
  end
end