require 'date'
require 'open-uri'
require 'nokogiri'

class UpcomingHouse
  # options, will look for current week unless prompted to do otherwise
  # pass in a date of the week you want as YYYY-MM-DD

  # gets data from unitedstates/congress/upcomming_house_floor

  def self.run(options = {})
    total_count = 0
    new_count = 0
    updated_count = 0
    upcoming_count = 0

    if options[:week]
      legislative_day = Date.parse(options[:week])
    else
      legislative_day = Date.today()
    end  
    
    mon = find_last_monday(legislative_day)
    week = mon.strftime('%Y%m%d')
    
    path = "data/unitedstates/congress"
    if not File.file?("#{path}/upcoming_house_floor/#{week}.json")
      puts "Weekly schedule not scraped by unitedstates/congress/upcomming_house_floor for week of #{mon}"
      return
    end

    upcoming_house_json = File.read("#{path}/upcoming_house_floor/#{week}.json")
    upcoming_house_data = Oj.load upcoming_house_json

    congress = upcoming_house_data['congress']
    legislative_day = upcoming_house_data['week_of']

    bills = upcoming_house_data['upcoming']

    bills.each do |bill|
      next if bill['bill_id'].nil?
      # check for valid bills
      bill_id = bill['bill_id']
      draft_bill_id = bill['draft_bill_id']

      scheduled_at = bill['added_at']
      description = bill['description']
      consideration = bill['consideration']
      floor_id = bill['floor_item_id']
      bill['files'].each do |file|
        if file['format'] = 'pdf'
          url = file['url']
        elsif file['format'] = 'xml'
          xml_url = file['url']
        end

        # I think I don't still need this? ----
        # clear out associations at /bill
        # Utils.flush_bill_upcoming! source_type

      #go through each bill ID, create or update entry.
      # update (overwrite) if we already have a record for:
      #   legislative_day
      #   range
      #   chamber
      #   bill_id
      
      # update should ONLY update these fields:
      #   bill
      
      # source_type, congress, url - won't change
      
      #This should NEVER overwrite scheduled_at.
      

        upcoming = UpcomingBill.where(
          legislative_day: legislative_day,
          range: "week",
          chamber: "house",
          
          bill_id: bill_id,
          # now tracking draft bills too
          draft_bill_id: draft_bill_id,

        ).first

        if upcoming.nil?
          upcoming = UpcomingBill.new(
            legislative_day: legislative_day,
            range: "week",
            chamber: "house",
            bill_id: bill_id,
            draft_bill_id: draft_bill_id,

            # only set on create
            scheduled_at: Time.now,

            congress: congress,
            source_type: "house_docs",
            url: "http://docs.house.gov/floor/Default.aspx?date=#{legislative_day}",
            
            bill_url: url,
            description: description,
            consideration: consideration,
            floor_id: floor_id,

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
    Report.success self, "Saved #{upcoming_count} upcoming bills (#{new_count} new, #{updated_count} updated) for the House for #{legislative_day}"
  end

  # should work for both daily and weekly house notices
  # http://www.majorityleader.gov/floor/
  #
  
  def self.details_from(url, doc)
    # Do I still need this?
    source_url = nil

    daily_section = doc.css('div#daily')
    puts daily_section
    date_text = daily_section.css('h5.post-title')[0].text
    date = Utils.utc_parse(date_text).strftime "%Y-%m-%d"

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

  def self.find_last_monday(date)
    if date.monday?
      mon = date
    elsif date.tuesday?
      mon = date - 1
    elsif date.wednesday?
      mon = date - 2
    elsif date.thursday?
      mon = date - 3
    elsif date.friday?
      mon = date - 4
    elsif date.saturday?
      mon = date - 5
    elsif date.sunday?
      mon = date - 6
    end
    return mon
  end

end