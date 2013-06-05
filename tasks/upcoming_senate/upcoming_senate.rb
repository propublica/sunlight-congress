# encoding: utf-8

require 'nokogiri'

class UpcomingSenate

  def self.run(options = {})
    count = 0

    url = "http://democrats.senate.gov/floor/daily-summary/feed/"

    unless body = Utils.download(url)
      Report.warning self, "Problem downloading the Senate Daily Summary feed, can't go on.", url: url
      return
    end

    doc = Nokogiri::XML body
    doc.remove_namespaces!

    # clear out Senate's upcoming records, this will replace them
    Utils.flush_bill_upcoming! "senate_daily"

    bad_entries = []
    upcoming_bills = {}

    # go from most recent to oldest - stop after the most recent valid entry
    (doc / :item).each do |item|
      item_doc = Nokogiri::HTML item.at("encoded").text

      since = options[:since] ? Utils.utc_parse(options[:since]) : Time.now.midnight.utc

      # second opinion on date
      post_date = Time.parse item.at("pubDate").text

      # There are now a bunch of "State Work Period" entries in the feed, going forward in time through September
      # Just ignore them
      title = item.at("title").text
      next unless title =~ /Schedule/i
      next unless legislative_date = Utils.utc_parse(title)
      next if legislative_date > 6.months.from_now # sanity check for future posts

      # don't care unless it's today or in the future
      if (legislative_date.midnight < since.midnight) or
          (post_date.midnight < since.midnight)
        puts "[#{legislative_date.strftime "%Y-%m-%d"}|#{post_date.strftime "%Y-%m-%d"}] Skipping, too old" if options[:debug]
        next
      end

      legislative_day = legislative_date.strftime "%Y-%m-%d"
      congress = Utils.congress_for_year legislative_date.year




      upcoming_bills[legislative_day] = {}
      text_pieces = []
      day_bill_ids = []

      lis = nil
      if root = item_doc.at("/html/body/ul")
        lis = root.xpath "li"
      else
        lis = item_doc.at("/html/body").element_children
      end

      lis.each_with_index do |li, i|
        text = li.text
        next unless text.present?

        # figure out the text item, including any following sub-items
        if li.next_element and li.next_element.name == "ul"
          text << "\n"
          li.next_element.xpath("li").each do |subitem|
            text << "\n* #{subitem.text}"
          end
        end

        text = clean_text text

        text_pieces << text

        bill_ids = Utils.bill_ids_for text, congress
        day_bill_ids += bill_ids

        bill_ids.each do |bill_id|
          if upcoming_bills[legislative_day][bill_id]
            upcoming_bills[legislative_day][bill_id][:context] << text
          else
            upcoming_bills[legislative_day][bill_id] = {
              bill_id: bill_id,
              source_type: "senate_daily",

              congress: congress,
              chamber: "senate",
              legislative_day: legislative_day,
              range: "day",
              url: item.at("link").text,

              context: text
            }
            if bill = Utils.bill_for(bill_id)
              upcoming_bills[legislative_day][bill_id][:bill] = bill
            end
          end
        end
      end
    end

    # create any accumulated upcoming bills
    upcoming_bills.each do |legislative_day, bills|
      puts "[#{legislative_day}] Storing #{bills.size} bill(s)..." if options[:debug]

      bills.each do |bill_id, bill|
        upcoming = UpcomingBill.create! bill

        # sync to bill object
        if upcoming[:bill]
          Utils.update_bill_upcoming! bill_id, upcoming
        end

        count += 1
      end

    end

    Report.success self, "Created or updated #{count} upcoming bills"

    if bad_entries.any?
      Report.warning self, "#{bad_entries.size} expected date-less titles in feed", :bad_entries => bad_entries
    end

  end

  def self.clean_text(text)
    text.
      gsub("\342\200\231", "'").
      gsub("\302\240", " ").
      gsub("\342\200\234", "\"").
      gsub("\342\200\235", "\"").
      strip
  end
end