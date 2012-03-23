require 'nokogiri'
require 'curb'
require 'tzinfo'


class BulkHouseVotes

  # Maintains a local copy of vote data from the House of Representatives.
  # 
  # By default, looks through the Clerk's EVS pages, and re/downloads data for all votes cast in the last 3 days.
  # Options can be passed in to archive whole years, which can ignore already downloaded files (to support resuming).
  # 
  # options:
  #   archive: archive the whole year, don't limit it to 3 days. Will not re-download existing files.
  #   force: if archiving, force it to re-download existing files.
  #
  #   year: the year of data to fetch (defaults to current year)
  #   limit: only download a certain number of votes (stop short, useful for testing/development)
  #   roll_id: only download a specific roll call vote. Ignores other options. 
  #     (examples: h902-2011, h24-2012)

  def self.run(options = {})
    year = Time.now.year
    
    count = 0
    bad_fetches = []

    
  end

  def self.download_to(url, dest, failures, cached, options)
    
    # only cache if we're trying to get through an archive, and we haven't passed the force option
    if File.exists?(dest) and options[:archive] and options[:force].blank?
      cached << {:url => url, :dest => dest}

    else
      puts "Downloading #{url} to #{dest}..." if options[:debug]
      unless result = system("curl #{url} --output #{dest} --silent")
        failures << {:url => url, :dest => dest}
      end
    end

  end
end