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
    
    Report.success self, "Updated or created #{total_count} House Dem whip notices"
    
    unless options[:party] == 'd'
      house_rep 'daily', HOUSE_REP_URL % "daily"
      house_rep 'weekly', HOUSE_REP_URL % "weekly"
    end
    
    Report.success self, "Updated or created daily and weekly House Rep whip notices"
  end
  
  def self.house_dem(type, url)
    # temporary: democraticwhip.gov is down, maybe done?
    return 0

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
      for_date = Utils.utc_parse entry.title
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
    
    permalink, posted_at = Utils.permalink_and_date_from_house_gop_whip_notice(url, doc)

    unless posted_at
      Report.warning self, "Couldn't find date in House Republican whip #{type} notice page, in either PDF or header, can't go on", :url => url
      return
    end

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
      :url => permalink,
      :session => session,
      :title => title
    }
    
    notice.save!
  end
  
  def self.content_for(url)
    begin
      open(url).read
    rescue Timeout::Error, Errno::ECONNRESET, Errno::ETIMEDOUT, Errno::ENETUNREACH
      nil
    end
  end
end