# encoding: utf-8

require 'nokogiri'

class FloorSenate

  # options:
  #   range: how many days before (or after) today to parse updates for.
  #          defaults to 1.
  #   no_sleep: don't sleep for 1s between updates - produces inaccurate data,
  #             but is tolerable to run in dev
  def self.run(options = {})
    range = options[:range] ? options[:range].to_i : 1

    count = 0
    failures = []

    html = nil
    begin
      html = Utils.curl "http://www.periodicalpress.senate.gov/?break_cache=#{Time.now.to_i}"
    rescue Timeout::Error, Errno::ECONNRESET, Errno::ETIMEDOUT, Errno::ENETUNREACH
      Report.warning self, "Network error on fetching the floor log, can't go on."
      return
    end

    doc = Nokogiri::HTML html

    unless container = doc.css("div.entry-content").first
      Report.warning self, "Can't locate title of the floor log, can't go on."
      return
    end

    # accumulate results in hash, keyed by date string, values are array of text updates
    updates = {}
    current_date = nil

    warnings = []

    (container.parent / :p).each do |item|
      # ignore headers and footer
      next if ["senate floor proceedings", "today's senate floor log", "\302\240"].include?(item.text.strip.downcase)
      next if [/archived floor logs/i, /floor lof is for reference only/i].find {|r| item.text.strip =~ r}

      if (item['style'] =~ /text-align: center/i) or (item['align'] == 'center')
        if Time.zone.parse(item.text)
          current_date = Utils.utc_parse(item.text).strftime "%Y-%m-%d"
          updates[current_date] ||= []
        else
          puts "Skipping center-aligned p with text #{item.text}" if options[:debug]
        end

      else # item['align'] == 'left' or item['align'].nil?
        if current_date.nil?
          warnings << {msg: "Unexpected HTML, got to an update without a date, skipping", text: item.text}
          next
        end

        updates[current_date] << clean_text(item.text)
      end
    end

    # We'll run this every 5 minutes, so we'll assign a timestamp to an item as soon we find it, if it doesn't exist already
    # If it does exist...we leave it alone.
    # This is *not* an archival script, and the timestamps will also be inaccurate at first - we must accept this.

    congress = Utils.current_congress

    today = Time.now.midnight

    updates.keys.sort.each do |legislative_day|
      # skip unless it's within a day of today
      this = Time.parse(legislative_day).midnight
      if (this > (today + range.days)) or (this < (today - range.days))
        next
      end

      todays = FloorUpdate.where(legislative_day: legislative_day).all.map {|u| u['update']}
      items = updates[legislative_day]

      # puts legislative_day

      items.each do |item|

        # leave existing items alone
        if todays.include?(item)
          puts "Found a dupe, ignoring" if options[:debug]
          next
        end

        floor_update = FloorUpdate.new(
          chamber: "senate",
          congress: congress,
          legislative_day: legislative_day,
          timestamp: Time.now,
          update: item,
          bill_ids: extract_bills(item),
          roll_ids: extract_rolls(item),
          legislator_ids: extract_legislators(item)
        )

        if floor_update.save
          count += 1
          puts "[#{floor_update.timestamp.strftime("%Y-%m-%d %H:%M:%S")}] New floor update on leg. day #{legislative_day}" if options[:debug]

          # sleep for a second so that if we discover multiple things at once on the same day it doesn't get the same timestamp
          sleep 1 unless options[:no_sleep]
        else
          failures << floor_update.attributes
          puts "Failed to save floor update, will file report"
        end
      end
    end

    if failures.any?
      Report.failure self, "Failed to save #{failures.size} floor updates.", failures: failures
    end

    if warnings.any?
      Report.warning self, "Warnings while scanning floor", warnings: warnings
    end

    Report.success self, "Saved #{count} new floor updates"
  end

  def self.extract_bills(text)
    congress = Utils.current_congress
    matches = text.scan(/((S\.|H\.)(\s?J\.|\s?R\.|\s?Con\.| ?)(\s?Res\.?)*\s?\d+)/i).map {|r| r.first}.uniq.compact
    matches.map {|code| "#{code.tr(" ", "").tr('.', '').downcase}-#{congress}" }
  end

  def self.extract_rolls(text)
    [] # unsure how to do this, they never use the roll number that I can see!
  end

  def self.extract_legislators(text)
    []
  end

  def self.clean_text(text)
    text.
      gsub("\342\200\231", "'").
      gsub("\302\240", " ").
      gsub("\342\200\234", "\"").
      gsub("\342\200\235", "\"").
      gsub(/[ \t]+/, ' ').
      gsub("\n", "\n\n").
      strip
  end

end