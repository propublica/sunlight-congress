require 'open-uri'
require 'nokogiri'

class UpcomingHouseDaily
  
  HOUSE_DEM_URL = 'http://www.democraticwhip.gov/rss/%s/all'
  HOUSE_REP_URL = 
  
  def self.run(options = {})
    total_count = 0
    
    url = "http://www.majorityleader.house.gov/floor/daily.html"
    
    begin
      html = open(url).read
    rescue Timeout::Error, Errno::ECONNRESET, Errno::ETIMEDOUT, Errno::ENETUNREACH
      Report.warning self, "Network error on fetching House Republican daily schedule, can't go on.", :url => url
      return
    end
    
    doc = Nokogiri::HTML html
    
    permalink, posted_at = Utils.permalink_and_date_from_house_gop_whip_notice(url, doc)

    unless posted_at
      Report.warning self, "Couldn't find date in House Republican daily schedule page, in either PDF or header, can't go on", :url => url
      return
    end
    
    legislative_day = posted_at.strftime("%Y-%m-%d")
    session = Utils.session_for_year posted_at.year
    
    element = doc.css("div#news_text").first
    unless element
      Report.failure self, "Couldn't find the House majority leader daily schedule content node, can't go on"
      return
    end
    
    schedule = UpcomingSchedule.find_or_initialize_by(
      :legislative_day => legislative_day,
      :source_type => "house_daily"
    )
    
    bill_ids = Utils.bill_ids_for element.text, session
    
    schedule.attributes = {
      :chamber => "house",
      :session => session,
      :original => element.to_html,
      :legislative_day => legislative_day,
      :bill_ids => bill_ids,
      :source_url => url
    }
    
    schedule.save!
    
    Report.success self, "Saved an upcoming schedule for the House for #{legislative_day}"
    
    
    # clear out existing upcoming bills for the day
    UpcomingBill.where(
      :source_type => "house_daily",
      :legislative_day => legislative_day
    ).delete_all
      
    upcoming_count = 0
    bill_ids.each do |bill_id|
      bill = Utils.bill_for bill_id

      upcoming = UpcomingBill.new(
        :session => session,
        :chamber => "house",
        :bill_id => bill_id,
        :legislative_day => legislative_day,
        :source_type => "house_daily",
        :source_url => url,
        :permalink => permalink
      )

      if bill and bill['abbreviated'] != true
        upcoming.attributes = {
          :bill => bill
        }
        Utils.update_bill_upcoming! bill_id, upcoming
      end

      upcoming.save!

      upcoming_count += 1
    end
    
    Report.success self, "Saved #{upcoming_count} upcoming bills for the House for #{legislative_day}"
    
  end
  
end