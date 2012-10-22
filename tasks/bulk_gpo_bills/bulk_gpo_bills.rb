require 'nokogiri'
require 'curb'

class BulkGpoBills

  # Maintains a local copy of bill data from GPO's FDSys system.
  # 
  # By default, looks through the current year's sitemap, and re/downloads all bills updated in the last 3 days.
  # Options can be passed in to archive whole years, or use cached data.
  # 
  # options:
  #   year: archive a year of data, don't limit it to 3 days
  #   cache: use cached data, don't re-download.
  #
  #   limit: only download a certain number of bills (stop short, useful for testing/development)
  #   bill_version_id: only download a specific bill version. ignores other options. 
  #     (examples: hr3590-111-ih, sres32-111-enr)

  def self.run(options = {})
    year = options[:year] ? options[:year].to_i : Time.now.year

    # only care about the last 3 days of new information by default
    # but allow for archiving of an entire year's sitemap
    archive_only_since = options[:year] ? nil : 3.days.ago.midnight.utc # 5am EST

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
        Report.warning self, "Couldn't load sitemap for #{year}"
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
      unless Utils.download(mods_url, options.merge(destination: mods_dest))
        failures << {url: mods_url, dest: mods_dest}
      end

      # sleep 0.1

      text_url = "http://www.gpo.gov/fdsys/pkg/BILLS-#{session}#{gpo_type}#{number}#{version_code}/html/BILLS-#{session}#{gpo_type}#{number}#{version_code}.htm"
      text_dest = "#{dest_prefix}.htm"
      unless Utils.download(text_url, options.merge(destination: text_dest))
        failures << {url: text_url, dest: text_dest}
      end

      # sleep 0.1

      xml_url = "http://www.gpo.gov/fdsys/pkg/BILLS-#{session}#{gpo_type}#{number}#{version_code}/xml/BILLS-#{session}#{gpo_type}#{number}#{version_code}.xml"
      xml_dest = "#{dest_prefix}.xml"
      unless Utils.download(xml_url, options.merge(destination: xml_dest))
        failures << {url: xml_url, dest: xml_dest}
      end

      # sleep 0.1

      count += 1
    end

    # only alert if there are more than a handful of failures, their service has occasional hiccups
    if failures.any? and failures.size > 10
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
    puts "[#{year}] Fetching sitemap from GPO..." if options[:debug]
    cache_url = "data/gpo/BILLS/sitemap-#{year}.xml"

    if body = Utils.download(url)
      Nokogiri::XML body
    end
  end

end