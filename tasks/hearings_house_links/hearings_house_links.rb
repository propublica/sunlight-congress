# encoding: utf-8

class HearingsHouseLinks

  # options:
  #   month: specific month to get hearings for (form: YYYY-MM)
  #   date: specific date to get hearings for (form: YYYY-MM-DD)

  def self.run(options = {})
    count = 0
    
    # read file
    path = Dir.pwd
    puts path
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
        hearing_type = hearing_data["house_meeting_type"]
        occurs_at = hearing_data["occurs_at"]
        room = hearing_data["room"]
        title = hearing_data["topic"]
        hearing_url = hearing_data["url"]
        
        if (room == "TBA") or (room =~ /(HOB|SOB|Office Building|Hart|Dirksen|Russell|Cannon|Longworth|Rayburn|Capitol)/)
          dc = true
        else
          dc = false
        end

        committee = Committee.where(committee_id: committee_id).first
        if subcommittee_suffix
          subcommittee_id = committee_id + subcommittee_suffix
          subcommittee = Committee.where(committee_id: subcommittee_id).first
        end
        
        
        ### look for event ID, chamber house
        hearing = Hearing.find_or_initialize_by house_hearing_id: house_event_id
        
        if hearing.new_record?
          puts "[#{committee_id}], #{house_event_id}, #{occurs_at}, Creating " 
        else
          puts "[#{committee_id}], #{house_event_id}, #{occurs_at}, Updating " 
        end
        
        if !hearing_url
          hearing_url = "http://docs.house.gov/Committee/Calendar/ByEvent.aspx?EventID=" + house_event_id
        end
        puts 6
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
    Report.success self, "Updated or created #{count} committee hearings for the House."
  end

  def self.committee_for(committee_name)
    # ignore case
    name = (committee_name !~ /^(?:House|Joint) /) ? "House #{committee_name}" : committee_name
    Committee.where(name: /^#{name}$/i).first
  end
## not in use
  # def self.subcommittee_for(subcommittee_name)
  #   subcommittee_name = subcommittee_name.gsub /^Subcommittee (on )?/i, ''
  #   subcommittee_name = subcommittee_name.gsub "&", "and"
  #   # known House mistake
  #   subcommittee_name = subcommittee_name.gsub "Oceans and Insular Affairs", "Oceans, and Insular Affairs"
  #   subcommittee = Committee.where(name: /^#{subcommittee_name}$/i).first
  #   subcommittee ? subcommittee.committee_id : nil
  # end

  # def self.room_for(room)
  #   return nil unless room
  #   room.sub(/House Office Building/i, "HOB").sub("Washington DC", "").strip
  # end

  # def self.split_header(header)
  #   bits = header.split(": ")
  #   type = bits.shift
  #   [type, bits.join(": ")]
  # end

  # def self.zero_prefix(month)
  #   if month < 10
  #     "0#{month}"
  #   else
  #     month.to_s
  #   end
  # end

  # def self.days_for(year, month)
  #   url = "http://house.gov/legislative/date/#{year}-#{zero_prefix month}-01"
  #   unless body = Utils.curl(url)
  #     Report.warning self, "Couldn't load month listing for #{year}-#{month} on House.gov committee hearings", url: url
  #     return []
  #   end

  #   doc = Nokogiri::HTML body
  #   links = doc.css("div.calendar table.calendar td a")
  #   links.map do |link|
  #     link['href'].split("/").last
  #   end
  # end

  # def self.remove_smart_characters(text)
  #   text.
  #     gsub("\342\200\231", "'").
  #     gsub("\302\240", " ").
  #     gsub("\342\200\234", "\"").
  #     gsub("\342\200\235", "\"")
  # end
  end
