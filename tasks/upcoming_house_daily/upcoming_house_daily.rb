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
    
    links = (doc / :a).select {|x| x.text =~ /printable pdf/i}
    a = links.first
    pdf_url = a['href']
    date_results = pdf_url.scan(/\/([^\/]+)\.pdf$/i)
    
    unless date_results.any? and date_results.first.any?
      Report.warning self, "Couldn't find PDF date in Republican daily schedule page, can't go on", :url => url
      return
    end
    
    date_str = date_results.first.first
    month, day, year = date_str.split "-"
    
    posted_at = Utils.noon_utc_for Time.local(year, month, day)
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
        :legislative_day => legislative_day,
        :source_type => "house_daily",
        :source_url => url,
        :bill_id => bill_id
      )

      if bill
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