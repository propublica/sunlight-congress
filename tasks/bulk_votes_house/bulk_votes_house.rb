require 'nokogiri'
require 'curb'
require 'tzinfo'


class BulkVotesHouse

  # Maintains a local copy of vote data from the House of Representatives.
  # 
  # By default, looks through the Clerk's EVS pages, and re/downloads data for the last 10 roll call votes.
  # Options can be passed in to archive whole years, which can ignore already downloaded files (to support resuming).
  # 
  # options:
  #   archive: archive the whole year, don't limit it to 1 days. Will not re-download existing files.
  #   force: if archiving, force it to re-download existing files.
  #
  #   year: the year of data to fetch (defaults to current year)
  #   limit: only download a certain number of votes (stop short, useful for testing/development)
  #   number: only download a specific roll call vote number for the given year. Ignores other options, except for year. 

  def self.run(options = {})
    year = options[:year] ? options[:year].to_i : Time.now.year
    initialize_disk! year

    latest = options[:latest] ? options[:latest].to_i : 10

    count = 0
    failures = []

    # fill with the numbers of the rolls to get for that year
    to_get = []

    if options[:number]
      to_get = [options[:number].to_i]
    else
      # count down from the top
      latest_roll = latest_roll_for year, options
      
      if options[:archive]
        from_roll = 1
      else
        from_roll = (latest_roll - latest) + 1
        from_roll = 1 if from_roll < 1
      end

      to_get = (from_roll..latest_roll).to_a.reverse
    end

    to_get.each do |number|
      url = url_for year, number
      dest = destination_for year, number

      puts "[#{year}][#{number}] Syncing..."
      download_roll url, dest, failures, options
      count += 1
    end

    if failures.any?
      Report.warning self, "Failed to download #{failures.size} files while syncing against the House Clerk votes collection for #{year}", :failures => failures
    end

    if options[:number]
      Report.success self, "Synced roll #{options[:number]} in #{year}"
    else
      Report.success self, "Synced files for #{count} House roll call votes for #{year}"
    end
  end

  def self.initialize_disk!(year)
    FileUtils.mkdir_p "data/house/rolls/#{year}"
  end

  def self.url_for(year, number)
    "http://clerk.house.gov/evs/#{year}/roll#{zero_prefix number}.xml"
  end

  def self.destination_for(year, number)
    "data/house/rolls/#{year}/#{zero_prefix number}.xml"
  end

  def self.zero_prefix(number)
    if number < 10
      "00#{number}"
    elsif number < 100
      "0#{number}"
    else
      number
    end
  end

  def self.download_roll(url, destination, failures, options = {})

    # only cache if we're trying to get through an archive, and we haven't passed the force option
    if File.exists?(destination) and options[:archive] and options[:force].blank?
      puts "\tCached at #{destination}, ignoring #{url}, pass force option to override" if options[:debug]

    else
      puts "\tDownloading #{url} to #{destination}" if options[:debug]
      if curl = Utils.curl(url, destination)
        
        # 404s come back as 200's, and are HTML documents
        if curl.content_type != "text/xml"
          failures << {:url => url, :destination => destination, :content_type => curl.content_type}
          return
        end

        # sanity check on files less than expected - 
        # most are ~82K, so if something is less than 80K, check the XML for malformed errors
        if curl.downloaded_content_length < 80000
          # retry once, quick check
          puts "\n\tRe-downloading once, looked truncated" if options[:debug]
          curl = Utils.curl(url, destination)
          
          if !curl or curl.downloaded_content_length < 80000
            # could add in a final Nokogiri::XML strict check, 
            # in case it really is short for some reason, but I haven't seen this happen yet
            failures << {:url => url, :destination => destination, :content_length => (curl ? curl.downloaded_content_length : nil)}
          end
        end

      else
        failures << {:url => url, :destination => destination}
      end
    end

  end

  # latest roll number on the House Clerk's listing of latest votes
  def self.latest_roll_for(year, options = {})
    url = "http://clerk.house.gov/evs/#{year}/index.asp"
    
    puts "[#{year}] Fetching index page for year from House Clerk..." if options[:debug]
    return nil unless doc = Utils.html_for(url)
    
    element = doc.css("tr td a").first
    return nil unless element and element.text.present?
    number = element.text.to_i
    number > 0 ? number : nil
  end
end