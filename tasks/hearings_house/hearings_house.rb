# encoding: utf-8

class HearingsHouse

  # options:
  #   month: specific month to get hearings for (form: YYYY-MM)
  #   date: specific date to get hearings for (form: YYYY-MM-DD)

  def self.run(options = {})
    count = 0
    bad_committee_lookups = []
    warnings = []
    meeting_type_codes = {"HHRG"=> "Hearing", "HMKP"=> "Markup", "HMTG"=> "Meeting"}
    # read file
    path = "data/unitedstates/congress"
    house_json = File.read "#{path}/committee_meetings_house.json"

    house_data = Oj.load house_json
    house_data.each do |hearing_data|
      if (hearing_data != nil)
        bill_ids = hearing_data["bills"]
        chamber = hearing_data["chamber"]
        committee_id = hearing_data["committee"]
        subcommittee_suffix = hearing_data["subcommittee"]
        congress = hearing_data["congress"]
        # used in govtrack
        guid = hearing_data["guid"]
        house_event_id = hearing_data["house_event_id"]
        hearing_type_code = hearing_data["house_meeting_type"]
        occurs_at = hearing_data["occurs_at"]
        room = hearing_data["room"]
        title = hearing_data["topic"]
        hearing_url = hearing_data["url"]

        if options[:date]
          occurs_day = Date.parse(occurs_at)
          date_check = Date.parse(options[:date])
          unless date_check == occurs_day
            next
          end
        end

        if options[:month]
          date_array = options[:month].split("-")
          month_check = date_array[1]
          year_check = date_array[0]
          month = hearing_data["occurs_at"][5,2]
          year = hearing_data["occurs_at"][0,4]
          unless month_check == month && year_check == year
            next
          end
        end

        if !hearing_url
          hearing_url = "http://docs.house.gov/Committee/Calendar/ByEvent.aspx?EventID=" + house_event_id
        end

        unless committee = Committee.where(committee_id: committee_id).first
          puts "Couldn't find committee by name #{committee_id}"
          bad_committee_lookups << {name: committee_name, url: hearing_url, date: occurs_at}
          next
        end

        unless hearing_type = meeting_type_codes[hearing_type_code]
          puts "Couldn't find meeting code #{hearing_type_code}"
          warnings << {name: hearing_type_code, url: hearing_url, date: occurs_at}
          hearing_type = "Other"
        end
        
        if subcommittee_suffix
          subcommittee_id = committee_id + subcommittee_suffix
          unless subcommittee = Committee.where(committee_id: subcommittee_id).first
            puts "Couldn't find subcommittee by name #{subcommittee_id}"
            bad_committee_lookups << {name: subcommittee_id, url: hearing_url, date: occurs_at}
          end
        end

        if room
          if (room == "TBA") 
            dc = true
          elsif (room =~ /(HOB|SOB|Office Building|Hart|Dirksen|Russell|Cannon|Longworth|Rayburn|Capitol)/)
            room = room_for(room)
            dc = true
          else
            dc = false
          end
        else
          dc = false
        end

        ### look for event ID, chamber house
        hearing = Hearing.find_or_initialize_by house_hearing_id: house_event_id
        
        if hearing.new_record?
          puts "[#{committee_id}], #{house_event_id}, #{occurs_at}, Creating " if options[:debug] 
        else
          puts "[#{committee_id}], #{house_event_id}, #{occurs_at}, Updating " if options[:debug] 
        end
        
        hearing.attributes = {
          chamber: chamber, 
          committee_id: committee_id,
          congress: congress,
          occurs_at: occurs_at,
          room: room,
          description: title,
          dc: dc,
          committee: Utils.committee_for(committee),
          bill_ids: bill_ids,
          # only from House right now
          url: hearing_url,
          hearing_type: hearing_type,
          house_hearing_id: house_event_id,
        }
        
  #### trying out subcommittee
        if subcommittee
          hearing[:subcommittee_id] = subcommittee_id
          hearing[:subcommittee] = Utils.committee_for(subcommittee)
          ## add warnings if lookup fails
        end
        
  ### add hearing info here
        hearing.save!
        count += 1
      end
    end
    
    if bad_committee_lookups.any?
      Report.warning self, "#{bad_committee_lookups.size} bad committee lookups", bad_committee_lookups: bad_committee_lookups
    end

    if warnings.any?
      Report.warning self, "#{warnings.size} warnings while looking up hearing schedules", warnings: warnings
    end

    Report.success self, "Updated or created #{count} committee hearings for the House."
  end

  def self.room_for(room_raw)
    if (room_raw =~ /(RHOB|LHOB|CHOB|Capitol)/) && room_raw != nil
      room = room_raw.sub("RHOB", "Rayburn HOB")
      room = room.sub("LHOB", "Longworth HOB")
      room = room.sub("CHOB", "Cannon HOB")
      room = room + ", Washington, D.C. 20515"
    else
      room = room_raw
    end
  end
end

