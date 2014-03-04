# encoding: utf-8

require 'nokogiri'

class UpcomingSenate

  def self.run(options = {})
    url = "http://democrats.senate.gov/floor/daily-summary/feed/"

    unless body = Utils.download(url)
      Report.warning self, "Problem downloading the Senate Daily Summary feed, can't go on.", url: url
      return
    end

    doc = Nokogiri::XML body
    doc.remove_namespaces!


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
      # if root = item_doc.at("/html/body/ul")
      #   lis = root.xpath "li"
      # else
        lis = item_doc.at("/html/body").element_children
      # end

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
              url: item.at("link").text,
              context: text,
              congress: congress
            }
          end
        end
      end
    end

    # clear out associations at /bill
    Utils.flush_bill_upcoming! "senate_daily"

    # create any accumulated upcoming bills
    #
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
    # context - this field is dumb, I don't care
    #
    # This should NEVER overwrite scheduled_at.
    #

    new_count = 0
    updated_count = 0
    upcoming_count = 0

    upcoming_bills.each do |legislative_day, bills|
      puts "[#{legislative_day}] Found #{bills.size} bill(s)..." if options[:debug]

      bills.each do |bill_id, details|
        upcoming = UpcomingBill.where(
          legislative_day: legislative_day,
          range: "day",
          chamber: "senate",
          bill_id: bill_id
        ).first

        if upcoming.nil?
          upcoming = UpcomingBill.new(
            legislative_day: legislative_day,
            range: "day",
            chamber: "senate",
            bill_id: bill_id,

            # only set on create
            scheduled_at: Time.now,

            context: details[:context],

            congress: details[:congress],
            source_type: "senate_daily",
            url: details[:url]
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

    end

    Report.success self, "Saved #{upcoming_count} upcoming bills (#{new_count} new, #{updated_count} updated) for the Senate"

    if bad_entries.any?
      Report.warning self, "#{bad_entries.size} expected date-less titles in feed", bad_entries: bad_entries
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