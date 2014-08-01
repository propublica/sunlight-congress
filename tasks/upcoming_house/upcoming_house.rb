require 'open-uri'
require 'nokogiri'

class UpcomingHouse
# not anymore
  # options:
  #
  #   range: "day" or "week" (default)

  def self.run(options = {})
    total_count = 0

    range = options[:range] || "week"

    page = {day: "daily", week: "weekly"}[range.to_sym]
    source_type = "house_#{page}"
    url = "http://www.majorityleader.gov/floor/"

    begin
      html = open(url).read
    rescue Timeout::Error, Errno::ECONNRESET, Errno::ETIMEDOUT, Errno::ENETUNREACH
      Report.warning self, "Network error on fetching House Republican daily schedule at- #{url}, can't go on.", :url => url
      return
    end

    doc = Nokogiri::HTML html

    source_url, legislative_day = details_from(url, doc)

    # we need a legislative day to anchor this around
    unless legislative_day
      Report.warning self, "Couldn't find date in House Republican daily schedule page, #{url}, can't go on", url: url
      return
    end

    # if the legislative day is in the past, never mind
    legislative_date = Utils.utc_parse legislative_day
    if (range == "week") and (legislative_date < 7.days.ago)
      puts "Weekly schedule's too old (#{legislative_day}), not storing anything"
      return
    elsif (range == "day") and (legislative_date < 1.day.ago)
      puts "Daily schedule's too old (#{legislative_day}), not storing anything"
      return
    end


    # grab the year and congress out of the date
    year = legislative_day.split("-").first
    congress = Utils.congress_for_year year

    # grab all bill IDs 
    if page == 'weekly'
      element = doc.css("div#weekly").first
    else
      element = doc.css("div#daily").first
    end

    unless element
      Report.failure self, "Couldn't find the House majority leader daily schedule content node, can't go on"
      return
    end

    bill_ids = Utils.bill_ids_for element.text, congress

    # clear out associations at /bill
    Utils.flush_bill_upcoming! source_type


    # go through each bill ID, create or update entry.
    # update (overwrite) if we already have a record for:
    #   legislative_day
    #   range
    #   chamber
    #   bill_id
    #
    # update should ONLY update these fields:
    #   bill
    #
    # source_type, congress, url - won't change
    #
    # This should NEVER overwrite scheduled_at.
    #
    new_count = 0
    updated_count = 0
    upcoming_count = 0

    bill_ids.each do |bill_id|

      upcoming = UpcomingBill.where(
        legislative_day: legislative_day,
        range: range,
        chamber: "house",

        bill_id: bill_id
      ).first

      if upcoming.nil?
        upcoming = UpcomingBill.new(
          legislative_day: legislative_day,
          range: range,
          chamber: "house",
          bill_id: bill_id,

          # only set on create
          scheduled_at: Time.now,

          congress: congress,
          source_type: source_type,
          url: source_url
        )
      end

      if upcoming.new_record?
        puts "[#{bill_id}] Saving a new record..." if options[:debug]
        new_count += 1
      else
        puts "[#{bill_id}] Updating an old record..." if options[:debug]
        updated_count += 1
      end

      # update bill data, even if schedule already existed
      if bill = Utils.bill_for(bill_id)
        upcoming['bill'] = bill
        Utils.update_bill_upcoming! bill_id, upcoming
      end

      upcoming.save!
      upcoming_count += 1
    end

    Report.success self, "Saved #{upcoming_count} upcoming bills (#{new_count} new, #{updated_count} updated) for the House for #{legislative_day}"

  end

  # should work for both daily and weekly house notices
  # http://majorityleader.gov/floor/#daily.html
  # http://majorityleader.gov/floor/#weekly.html
  #
  # If the PDF link is valid, and has a date in it, then use that date, and use it as the permalink
  # If not, extract the date from the header, and use the original url as the permalink
  def self.details_from(url, doc)
    # Do I still need this?
    source_url = nil

    daily_section = doc.css('div#daily')
    date_text = daily_section.css('h5.post-title')[0].text
    date = Utils.utc_parse(date_text).strftime "%Y-%m-%d"

### none of this works anymore
    # first preference is to get the date from the PDF URL
    # links = (doc / :a).select {|x| x.text =~ /printable pdf/i}
    # a = links.first
    # if a
    #   pdf_url = a['href']
    #   pdf_url
    #   date_results = pdf_url.gsub(/(DAILY|WEEKLY)%20/, '').gsub(/%20[^\.]*\.pdf/i, '.pdf').scan(/\/([^\/]+)\.pdf$/i)
    # end

    # if date_results and date_results.any? and date_results.first.any?
    #   date_text = date_results.first.first
    #   source_url = pdf_url

    #   month, day, year = date_text.split "-"
    #   year = ("20" + year) if year.size == 2
    #   date_text = [year, month, day].join "-"

    # # but if the PDF URL is messed up, try to get it from the header
    # else
    #   begin
    #     date_text = doc.css("#news_text").first.css("b").first.text
    #   rescue ArgumentError
    #     date = nil
    #   end
    # end

    month, day, year = date.split "-"
    year = ("20" + year) if year.size == 2
    date_text = [year, month, day].join "-"

    # sanity check, sometimes there are typos on the year
    if (year.to_i != Time.zone.now.year) and (Utils.utc_parse(date) < 6.months.ago)
      date_text.gsub! year, (year.to_i + 1).to_s
    end
    # I don't think source_urls is going to be used
    [source_url, date]
  end

  def self.zero_prefix(number)
    if number.to_i < 10
      "0#{number}"
    else
      number
    end
  end

end