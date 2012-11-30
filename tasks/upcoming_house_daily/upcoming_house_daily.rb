require 'open-uri'
require 'nokogiri'

class UpcomingHouseDaily
  
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
    
    permalink, posted_at = permalink_and_date_from_house_gop_whip_notice(url, doc)

    unless posted_at
      Report.warning self, "Couldn't find date in House Republican daily schedule page, in either PDF or header, can't go on", :url => url
      return
    end
    
    legislative_day = posted_at.strftime("%Y-%m-%d")
    congress = Utils.congress_for_year posted_at.year
    
    element = doc.css("div#news_text").first
    unless element
      Report.failure self, "Couldn't find the House majority leader daily schedule content node, can't go on"
      return
    end
    
    bill_ids = Utils.bill_ids_for element.text, congress
    
    
    # clear out existing upcoming bills for the day
    UpcomingBill.where(
      :source_type => "house_daily",
      :legislative_day => legislative_day
    ).delete_all
      
    upcoming_count = 0
    bill_ids.each do |bill_id|
      bill = Utils.bill_for bill_id

      upcoming = UpcomingBill.new(
        :congress => congress,
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

  # should work for both daily and weekly house notices
  # http://majorityleader.gov/floor/daily.html
  # http://majorityleader.gov/floor/weekly.html
  #
  # If the PDF link is valid, and has a date in it, then use that date, and use it as the permalink
  # If not, extract the date from the header, and use the original url as the permalink
  def self.permalink_and_date_from_house_gop_whip_notice(url, doc)
    date = nil
    permalink = url # default to the HTML page, unless we can get a valid PDF out of this

    # first preference is to get the date from the PDF URL
    links = (doc / :a).select {|x| x.text =~ /printable pdf/i}
    a = links.first

    date_results = nil

    if a
      pdf_url = a['href']
      date_results = pdf_url.scan(/\/([^\/]+)\.pdf$/i)
    end
    
    if date_results and date_results.any? and date_results.first.any?
      date_str = date_results.first.first
      month, day, year = date_str.split "-"
      date = Utils.noon_utc_for Time.local(year, month, day)
      permalink = pdf_url

    # but if the PDF URL is messed up, try to get it from the header
    else
      begin
        date = Date.parse doc.css("#news_text").first.css("b").first.text
        date = Utils.noon_utc_for date.to_time
      rescue ArgumentError
        date = nil
      end
    end

    [permalink, date]
  end
  
end