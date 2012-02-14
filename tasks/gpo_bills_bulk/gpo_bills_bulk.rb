require 'nokogiri'
require 'curb'

class GpoBillsBulk

  # maintains a local copy of data from GPO's FDSys system
  # options:
  #   year: the year of data to fetch (defaults to current year)
  #   limit: only download a certain number of bills, instead of the entire year's worth
  #   bill_version_id: only download a certain bill version (ignore the year) (examples: hr3590-112-ih, sres32-111-enr)

  def self.run(options = {})
    year = options[:year] ? options[:year].to_i : Time.now.year

    # pick a reasonable timeframe in which to ignore the cache, 
    # and to redownload anything marked as updated in this window
    rearchive_since = 7.days.ago.midnight.utc # 5am EST

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
        match = url.match /BILLS-(\d+)(hr|hres|hjres|hconres|s|sres|sjres|sconres)(\d+)([^\/]+)\//
        bill_versions << [match[2], match[3], match[1], match[4]]
      end
    end

    if options[:limit]
      bill_versions = bill_versions[0...(options[:limit].to_i)]
    end

    count = 0
    failures = []
    cached = []

    bill_versions.each do |gpo_type, number, session, version_code|
      bill_type = gpo_type.sub 'con', 'c'
      dest_prefix = "data/gpo/BILLS/#{session}/#{bill_type}/#{bill_type}#{number}-#{session}-#{version_code}"

      mods_url = "http://www.gpo.gov/fdsys/pkg/BILLS-#{session}#{gpo_type}#{number}#{version_code}/mods.xml"
      mods_dest = "#{dest_prefix}.mods.xml"
      download_to mods_url, mods_dest, failures, cached, options

      text_url = "http://www.gpo.gov/fdsys/pkg/BILLS-#{session}#{gpo_type}#{number}#{version_code}/html/BILLS-#{session}#{gpo_type}#{number}#{version_code}.htm"
      text_dest = "#{dest_prefix}.htm"
      download_to text_url, text_dest, failures, cached, options

      xml_url = "http://www.gpo.gov/fdsys/pkg/BILLS-#{session}#{gpo_type}#{number}#{version_code}/xml/BILLS-#{session}#{gpo_type}#{number}#{version_code}.xml"
      xml_dest = "#{dest_prefix}.xml"
      download_to xml_url, xml_dest, failures, cached, options

      count += 1
    end

    if failures.any?
      Report.warning self, "Failed to download #{failures.size} files while syncing against GPOs BILLS collection for #{year}", :failures => failures
    end

    if cached.any?
      Report.note self, "Didn't bother downloading #{cached.size} cached files for #{year}"
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

  def self.download_to(url, dest, failures, cached, options)
    
    if File.exists?(dest) and options[:bill_version_id].blank? and options[:force].blank?
      cached << {:url => url, :dest => dest}
    else
      puts "Downloading #{url} to #{dest}..." if options[:debug]
      unless result = system("curl #{url} --output #{dest} --silent")
        failures << {:url => url, :dest => dest}
      end
    end

  end

end