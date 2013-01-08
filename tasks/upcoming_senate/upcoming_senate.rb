# encoding: utf-8

require 'feedzirra'
require 'nokogiri'

class UpcomingSenate
  
  def self.run(options = {})
    count = 0
    
    url = "http://democrats.senate.gov/floor/daily-summary/feed/"
    
    rss = nil
    begin
      rss = Feedzirra::Feed.fetch_and_parse url, :timeout => 20
    rescue Exception => ex
      Report.warning self, "Network error on fetching Senate Daily Summary feed, can't go on.", :url => url
      return
    end

    if rss.is_a?(Fixnum)
      Report.note self, "Got status code #{rss} from Senate Daily Summary feed, can't go on.", :url => url
      return
    elsif rss.nil?
      Report.warning self, "Got a nil return value from Feedzirra from the Senate Daily Summary feed, can't go on.", :url => url
      return
    end

    # clear out Senate's upcoming records, this will replace them
    UpcomingBill.where(source_type: "senate_daily").delete_all

    bad_entries = []
    upcoming_bills = {}
    
    # go from most recent to oldest - stop after the most recent valid entry
    rss.entries.each do |entry|
      doc = Nokogiri::HTML entry.content
      
      # There are now a bunch of "State Work Period" entries in the feed, going forward in time through September
      # Just ignore them
      next unless entry.title =~ /Schedule/i
      next unless legislative_date = Utils.utc_parse(entry.title)
      next if legislative_date > 6.months.from_now # sanity check
      
      legislative_day = legislative_date.strftime "%Y-%m-%d"
      congress = Utils.congress_for_year legislative_date.year
      
      since = options[:since] ? Utils.utc_parse(options[:since]) : Time.now.midnight.utc
      
      # don't care unless it's today or in the future
      if legislative_date.midnight < since.midnight
        puts "[#{legislative_day}] Skipping, too old" if options[:debug]
        next
      end
      
      upcoming_bills[legislative_day] = {}
      text_pieces = []
      day_bill_ids = []
      
      items = nil
      if root = doc.at("/html/body/ul")
        items = root.xpath "li"
      else
        items = doc.at("/html/body").element_children
      end
      
      items.each_with_index do |item, i|
        text = item.text
        next unless text.present?
            
        # figure out the text item, including any following sub-items
        if item.next_element and item.next_element.name == "ul"
          text << "\n"
          item.next_element.xpath("li").each do |subitem|
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
              url: entry.url,

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