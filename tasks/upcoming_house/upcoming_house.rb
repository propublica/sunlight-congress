require 'open-uri'
require 'nokogiri'

class UpcomingHouse
  
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
    
    url, legislative_day = details_from(url, doc)

    unless legislative_day
      Report.warning self, "Couldn't find date in House Republican daily schedule page, in either PDF or header, can't go on", :url => url
      return
    end
    
    year = legislative_day.split("-").first
    congress = Utils.congress_for_year year
    
    element = doc.css("div#news_text").first
    unless element
      Report.failure self, "Couldn't find the House majority leader daily schedule content node, can't go on"
      return
    end
    
    bill_ids = Utils.bill_ids_for element.text, congress
    
    
    # clear out existing upcoming bills for the day
    UpcomingBill.where(
      source_type: "house_daily",
      legislative_day: legislative_day
    ).delete_all
      
    upcoming_count = 0
    bill_ids.each do |bill_id|
      bill = Utils.bill_for bill_id

      upcoming = UpcomingBill.new(
        bill_id: bill_id,
        source_type: "house_daily",

        congress: congress,
        chamber: "house",
        legislative_day: legislative_day,
        url: url
      )

      if bill
        upcoming['bill'] = bill
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
  def self.details_from(url, doc)
    date = nil

    # first preference is to get the date from the PDF URL
    links = (doc / :a).select {|x| x.text =~ /printable pdf/i}
    a = links.first

    date_results = nil

    if a
      pdf_url = a['href']
      date_results = pdf_url.scan(/\/([^\/]+)\.pdf$/i)
    end
    
    if date_results and date_results.any? and date_results.first.any?
      date_text = date_results.first.first
      url = pdf_url

      month, day, year = date_text.split "-"
      year = ("20" + year) if year.size == 2
      date_text = [year, month, day].join "-"

    # but if the PDF URL is messed up, try to get it from the header
    else
      begin
        date_text = doc.css("#news_text").first.css("b").first.text
      rescue ArgumentError
        date = nil
      end
    end

    date = Utils.utc_parse(date_text).strftime "%Y-%m-%d"

    [url, date]
  end

  def self.zero_prefix(number)
    if number.to_i < 10
      "0#{number}"
    else
      number
    end
  end
  
end