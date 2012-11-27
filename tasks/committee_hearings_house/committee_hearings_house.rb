# encoding: utf-8

require 'nokogiri'

class CommitteeHearingsHouse

  def self.run(options = {})
    count = 0
    bad_committee_lookups = []

    # if a specific date, do just that date
    if options[:date]
      count += hearings_for_day options[:date], bad_committee_lookups, options
    else

      # if a specific month is given (form "YYYY-MM")
      if options[:month]
        months = [options[:month].split("-").map(&:to_i)] 

      # otherwise, default to this month and next month
      else
        this_year = Time.now.year
        this_month = Time.now.month

        if this_month == 12
          next_year = this_year + 1
          next_month = 1
        else
          next_year = this_year
          next_month = this_month + 1
        end

        months = [[this_year, this_month], [next_year, next_month]]
      end

      months.each do |year, month|
        puts "Fetching dates for #{year}-#{zero_prefix month}..."
        dates = days_for year, month

        dates.each do |datestamp|
          count += hearings_for_day datestamp, bad_committee_lookups, options
        end
      end
    end

    if bad_committee_lookups.any?
      Report.warning self, "#{bad_committee_lookups.size} bad committee lookups", bad_committee_lookups: bad_committee_lookups
    end

    Report.success self, "Updated or created #{count} committee hearings for the House."
  end

  def self.hearings_for_day(datestamp, bad_committee_lookups, options)
    puts "Fetching hearings for #{datestamp}..."

    url = "http://house.gov/legislative/date/#{datestamp}"
    unless body = Utils.curl(url)
      Report.warning self, "Couldn't load day listing for #{datestamp} on House.gov committee hearings", url: url
      return 0
    end

    # body = body.encode("ASCII-8BIT", :invalid => :replace, :undef => :replace)

    year, month, day = datestamp.split("-")

    count = 0

    session = Utils.session_for_year year.to_i
    chamber = "house"

    doc = Nokogiri::HTML body
    headers = doc.css("#contentMain h3")
    bodies = doc.css("#contentMain p")

    # each h3 is a hearing/whatever name, the p has the details
    while headers.any?
      h3 = headers.shift
      body = bodies.shift

      header = h3.inner_text.strip
      hearing_type, title = split_header header
      title = remove_smart_characters title
      hearing_url = h3.at("a")['href']

      committee_name = body.at("a").inner_text.strip
      unless committee = committee_for(committee_name)
        puts "Couldn't find committee by name #{committee_name}" if options[:debug]
        bad_committee_lookups << {name: committee_name, url: url, date: datestamp}
        next
      end
      committee_id = committee.committee_id

      # split up the body text into pieces
      body_text = body.inner_text.strip

      # treat as ASCII, just ditch or collapse special characters
      body_text = body_text.encode("ASCII-8BIT", :invalid => :replace, :undef => :replace)

      top_line, bottom_line = body_text.split(/\s*\n\s*/).map &:strip
      top_pieces = top_line.split(/\s+\|\s+/).map &:strip
      bottom_pieces = bottom_line.split(/\s+\|\s+/).map &:strip
      
      # first piece is reliably the time
      time_of_day = top_pieces.first
      occurs_at = Time.zone.parse("#{datestamp} #{time_of_day}").utc

      # second piece is the room, may not be there
      room = room_for(top_pieces[1]) || "TBA"
      dc = ((room == "TBA") or !(room =~ /HOB/).nil?)

      # first piece of bottom is the host, but we extracted that more reliably already
      # second piece of bottom is the subcommittee name, or "Full Committee"

      if bottom_pieces[1] and (bottom_pieces[1] =~ /subcommittee[^s]/i)
        unless subcommittee_id = subcommittee_for(bottom_pieces[1])
          bad_committee_lookups << bottom_pieces[1]
        end
      else
        subcommittee_id = nil
      end

      bill_ids = bill_ids_for title, session

      hearing = CommitteeHearing.where(
        chamber: chamber, 
        committee_id: committee_id, 
        "$or" => [{occurs_at: occurs_at}, {description: title}]
      ).first || CommitteeHearing.new(chamber: chamber, committee_id: committee_id)

      if hearing.new_record?
        puts "Creating new committee hearing for #{committee_id} at #{occurs_at}..." if options[:debug]
      end

      hearing.attributes = {
        # core
        occurs_at: occurs_at,
        description: title,
        room: room,
        legislative_day: datestamp,
        session: session,
        committee: Utils.committee_for(committee),

        # optional
        time_of_day: time_of_day,
        bill_ids: bill_ids,

        # only from House right now
        hearing_url: hearing_url,
        hearing_type: hearing_type,
        dc: dc
      }

      if subcommittee_id
        hearing[:subcommittee_id] = subcommittee_id
      end

      hearing.save!
      count += 1
    end

    count
  end

  # doesn't handle subcommittees right now
  def self.committee_for(committee_name)
    # ignore case
    name = (committee_name !~ /^(?:House|Joint) /) ? "House #{committee_name}" : committee_name
    Committee.where(name: /^#{name}$/i).first
  end

  def self.subcommittee_for(subcommittee_name)
    subcommittee_name = subcommittee_name.gsub /^Subcommittee (on )?/i, ''
    
    # known House mistake
    subcommittee_name = subcommittee_name.gsub "Oceans and Insular Affairs", "Oceans, and Insular Affairs"

    subcommittee = Committee.where(name: /^#{subcommittee_name}$/i).first
    subcommittee ? subcommittee.committee_id : nil
  end

  def self.room_for(room)
    return nil unless room
    room.sub(/House Office Building/i, "HOB").sub("Washington DC", "").strip
  end

  def self.split_header(header)
    bits = header.split(": ")
    type = bits.shift
    [type, bits.join(": ")]
  end

  def self.zero_prefix(month)
    if month < 10
      "0#{month}"
    else
      month.to_s
    end
  end

  def self.days_for(year, month)
    url = "http://house.gov/legislative/date/#{year}-#{zero_prefix month}-01"
    unless body = Utils.curl(url)
      Report.warning self, "Couldn't load month listing for #{year}-#{month} on House.gov committee hearings", url: url
      return []
    end

    doc = Nokogiri::HTML body
    links = doc.css("div.calendar table.calendar td a")
    links.map do |link|
      link['href'].split("/").last
    end
  end

  def self.bill_ids_for(string, session)
    string.scan(/((S\.|H\.)(\s?J\.|\s?R\.|\s?Con\.| ?)(\s?Res\.)*\s?\d+)/i).map do |match|
      "#{match[0].downcase.gsub(/[\s\.]/, '').gsub("con", "c")}-#{session}"
    end.uniq
  end

  def self.remove_smart_characters(text)
    text.
      gsub("\342\200\231", "'").
      gsub("\302\240", " ").
      gsub("\342\200\234", "\"").
      gsub("\342\200\235", "\"")
  end

end