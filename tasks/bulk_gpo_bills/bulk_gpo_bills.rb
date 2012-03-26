require 'nokogiri'
require 'curb'

class BulkGpoBills

  # Maintains a local copy of bill data from GPO's FDSys system.
  # 
  # By default, looks through the current year's sitemap, and re/downloads all bills updated in the last 3 days.
  # Options can be passed in to archive whole years, which can ignore already downloaded files.
  # 
  # options:
  #   archive: archive the whole year, don't limit it to 3 days. Will not re-download existing files.
  #   force: if archiving, force it to re-download existing files.
  #
  #   year: the year of data to fetch (defaults to current year)
  #   limit: only download a certain number of bills (stop short, useful for testing/development)
  #   bill_version_id: only download a specific bill version. ignores other options. 
  #     (examples: hr3590-112-ih, sres32-111-enr)

  def self.run(options = {})
    year = options[:year] ? options[:year].to_i : Time.now.year

    # only care about the last 3 days of new information by default
    # but allow for archiving of an entire year's sitemap
    archive_only_since = options[:archive] ? nil : 3.days.ago.midnight.utc # 5am EST

    # populate with bill info to fetch
    bill_versions = [] # holds arrays with: [gpo_type, number, session, version_code]

    if options[:bill_version_id]
      bill_type, number, session, version_code = options[:bill_version_id].match(/(hr|hres|hjres|hcres|s|sres|sjres|scres)(\d+)-(\d+)-(\w+)$/).captures
      gpo_type = bill_type.sub 'c', 'con'
      bill_versions = [[gpo_type, number, session, version_code]]

      # initialize the disk for whatever session this bill version is
      initialize_disk session

    else
      # initialize disk, with buffer in case the sitemap references a past session (it happens)
      current_session = Utils.session_for_year year
      (current_session - 2).upto(current_session) do |session|
        initialize_disk session
      end

      unless sitemap_doc = sitemap_doc_for(year, options)
        Report.warning "Couldn't load sitemap for #{year}"
        return
      end

      (sitemap_doc / :url).map do |update|
        url = update.at("loc").text
        modified = Time.parse update.at("lastmod").text

        if !archive_only_since or (modified > archive_only_since)
          match = url.match /BILLS-(\d+)(hr|hres|hjres|hconres|s|sres|sjres|sconres)(\d+)([^\/]+)\//
          bill_versions << [match[2], match[3], match[1], match[4]]
        end
      end
    end

    if options[:limit]
      bill_versions = bill_versions[0...(options[:limit].to_i)]
    end

    count = 0
    failures = []
    
    bill_versions.each do |gpo_type, number, session, version_code|
      bill_type = gpo_type.sub 'con', 'c'
      dest_prefix = "data/gpo/BILLS/#{session}/#{bill_type}/#{bill_type}#{number}-#{session}-#{version_code}"

      mods_url = "http://www.gpo.gov/fdsys/pkg/BILLS-#{session}#{gpo_type}#{number}#{version_code}/mods.xml"
      mods_dest = "#{dest_prefix}.mods.xml"
      download_to mods_url, mods_dest, failures, options

      text_url = "http://www.gpo.gov/fdsys/pkg/BILLS-#{session}#{gpo_type}#{number}#{version_code}/html/BILLS-#{session}#{gpo_type}#{number}#{version_code}.htm"
      text_dest = "#{dest_prefix}.htm"
      download_to text_url, text_dest, failures, options

      xml_url = "http://www.gpo.gov/fdsys/pkg/BILLS-#{session}#{gpo_type}#{number}#{version_code}/xml/BILLS-#{session}#{gpo_type}#{number}#{version_code}.xml"
      xml_dest = "#{dest_prefix}.xml"
      download_to xml_url, xml_dest, failures, options

      count += 1
    end

    if failures.any?
      Report.warning self, "Failed to download #{failures.size} files while syncing against GPOs BILLS collection for #{year}", :failures => failures
    end

    if options[:bill_version_id]
      Report.success self, "Synced bill version #{options[:bill_version_id]}"
    else
      Report.success self, "Synced files for #{count} bill versions for sitemap #{year}"
    end
  end

  def self.initialize_disk(session)
    ["hr", "hres", "hjres", "hcres", "s", "sres", "sjres", "scres"].each do |bill_type|
      FileUtils.mkdir_p "data/gpo/BILLS/#{session}/#{bill_type}"
    end
  end

  def self.sitemap_doc_for(year, options = {})
    url = "http://www.gpo.gov/smap/fdsys/sitemap_#{year}/#{year}_BILLS_sitemap.xml"
    begin
      puts "[#{year}] Fetching sitemap from GPO..." if options[:debug]
      curl = Curl::Easy.new url
      curl.follow_location = true
      curl.perform
    rescue Timeout::Error, Errno::ECONNRESET, Errno::ETIMEDOUT, Errno::ENETUNREACH
      Report.warning self, "Timeout while fetching sitemap, aborting for now", :url => url
      return nil
    end

    Nokogiri::XML curl.body_str
  end

  def self.download_to(url, dest, failures, options)
    
    # only cache if we're trying to get through an archive, and we haven't passed the force option
    if File.exists?(dest) and options[:archive] and options[:force].blank?
      # it's cached, don't re-download

    else
      puts "Downloading #{url} to #{dest}..." if options[:debug]
      unless Utils.curl(url, dest)
        failures << {:url => url, :dest => dest}
      end
    end

  end

end