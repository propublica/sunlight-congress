require 'open-uri'
require 'nokogiri'

class UpcomingHouse

  # options:
  #
  #   range: "day" or "week" (default)

  def self.run(options = {})
    total_count = 0

    range = options[:range] || "week"

    page = {day: "daily", week: "weekly"}[range.to_sym]
    source_type = "house_#{page}"
    url = "http://majorityleader.gov/floor/#{page}.html"

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


    # flush existing records for this source type
    Utils.flush_bill_upcoming! source_type

    # old-ness check must come after flush
    legislative_date = Utils.utc_parse legislative_day
    if (range == "week") and (legislative_date < 7.days.ago)
      puts "Weekly schedule's too old (#{legislative_day}), not storing anything"
      return
    elsif (range == "day") and (legislative_date < 1.day.ago)
      puts "Daily schedule's too old (#{legislative_day}), not storing anything"
      return
    end


    upcoming_count = 0
    bill_ids.each do |bill_id|

      upcoming = UpcomingBill.new(
        source_type: source_type,
        legislative_day: legislative_day,
        range: range,

        bill_id: bill_id,

        congress: congress,
        chamber: "house",
        url: url
      )

      if bill = Utils.bill_for(bill_id)
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
      pdf_url
      date_results = pdf_url.gsub(/(DAILY|WEEKLY)%20/, '').gsub(/%20[^\.]*\.pdf/i, '.pdf').scan(/\/([^\/]+)\.pdf$/i)
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

    # sanity check, sometimes there are typos on the year
    if (year.to_i != Time.zone.now.year) and (Utils.utc_parse(date_text) < 6.months.ago)
      date_text.gsub! year, (year.to_i + 1).to_s
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