require 'nokogiri'
require 'us-documents'

class BillsText

  # Indexes full text of versions of bills into ElasticSearch.
  #
  # options:
  #   congress: which congress (e.g. 111, 112) of Congress to load
  #   limit: number of bills to stop at (useful for development)
  #   bill_id: index only a specific bill.

  def self.run(options = {})
    bill_count = 0
    version_count = 0

    if options[:bill_id]
      targets = [options[:bill_id]]
    else
      congress = options[:congress] ? options[:congress].to_i : Utils.current_congress
      targets = Bill.where(congress: congress).distinct :bill_id

      if options[:limit]
        targets = targets.first options[:limit].to_i
      end
    end

    warnings = []
    notes = []
    gpo_missing = []

    # used to keep batches of indexes
    batcher = []

    targets.to_a.each do |bill_id|
      type, number, congress, chamber = Utils.bill_fields_from bill_id

      # load in bill for this ID
      bill = Bill.where(bill_id: bill_id).first


      # ES will index a bill's basic fields plus these others
      es_only = Utils.bill_for(bill).merge(
        sponsor: bill['sponsor'],
        last_action: bill['last_action'],
        summary: bill['summary'],
        summary_short: bill['summary_short'],
        keywords: bill['keywords'],
        titles: bill['titles']
      )

      mongo_only = {}

      # new fields to go into both ES and Mongo
      version_fields = {}


      # find all the versions of text for that bill
      version_files = Dir.glob("data/gpo/BILLS/#{congress}/#{type}/#{type}#{number}-#{congress}-[a-z]*.htm")

      if version_files.empty?
        gpo_missing << bill_id

        puts "[#{bill_id}] No text, using summary info and intro date..." if options[:debug]

        version_fields = {
          last_version_on: bill['introduced_on']
        }

      else

        # accumulate an array of version objects
        bill_versions = []

        version_files.each do |file|
          # strip off the version code
          bill_version_id = File.basename file, File.extname(file)
          version_code = bill_version_id.match(/\-(\w+)$/)[1]

          # standard GPO version name
          version_name = Utils.bill_version_name_for version_code

          # metadata from associated GPO MODS file
          # -- MODS file is a constant reasonable size no matter how big the bill is

          mods_file = "data/gpo/BILLS/#{congress}/#{type}/#{bill_version_id}.mods.xml"
          mods_doc = nil
          if File.exists?(mods_file)
            mods_doc = Nokogiri::XML open(mods_file)
          end

          issued_on = nil # will get filled in
          urls = nil # may not...
          pages = nil

          if mods_doc
            issued_on = issued_on_for mods_doc
            urls = urls_for mods_doc
            pages = pages_for mods_doc

            if issued_on.blank?
              warnings << {message: "Had MODS data but no date available for #{bill_version_id}, SKIPPING"}
              next
            end

          else
            puts "[#{bill_id}][#{version_code}] No MODS data, skipping!" if options[:debug]

            # hr81-112-enr is known to trigger this, but that looks like a mistake on GPO's part (HR 81 was never voted on)
            # So if any other bill triggers this, send me a warning so I can check it out.
            if bill_version_id != "hr81-112-enr"
              warnings << {message: "No MODS data available for #{bill_version_id}, SKIPPING"}
            end

            # either way, skip over the bill version, it's probably invalid
            next
          end


          # read in full text
          full_doc = Nokogiri::HTML File.read(file)
          full_text = full_doc.at("pre").text
          full_text = clean_text full_text

          # write text to disk if asked
          Utils.write(text_cache(congress, bill_id), full_text) if options[:cache_text]



          # put up top here because it's the first line of debug output for a bill
          puts "[#{bill_id}][#{version_code}] Processing..." if options[:debug]


          version_count += 1

          bill_versions << {
            version_code: version_code,
            issued_on: issued_on,
            version_name: version_name,
            bill_version_id: bill_version_id,
            urls: urls,
            pages: pages,

            # only the last version's text will ultimately be saved in ES
            text: full_text
          }
        end

        if bill_versions.size == 0
          warnings << {message: "No versions with a valid date found for bill #{bill_id}, SKIPPING update of the bill entirely in ES and Mongo", bill_id: bill_id}
          next
        end

        bill_versions = bill_versions.sort_by {|v| v[:issued_on]}
        last_version = bill_versions.last
        last_version_text = last_version[:text].dup
        last_version_on = last_version[:issued_on]

        # don't store the full text (except the last version's text we preserved, in ES only)
        bill_versions.each {|v| v.delete :text}


        unless citation_ids = Utils.citations_for(bill, last_version_text, citation_cache(congress, bill_id), options)
          warnings << {message: "Failed to extract citations from #{bill.bill_id}, version code: #{last_version[:version_code]}"}
          citation_ids = []
        end

        version_fields = {
          last_version: last_version,
          last_version_on: last_version_on,
          citation_ids: citation_ids,
        }

        mongo_only.merge! versions: bill_versions
        es_only.merge! text: last_version_text
      end


      # Update bill in Mongo

      bill.attributes = version_fields.merge(mongo_only)
      bill.save!
      puts "[#{bill_id}] Updated bill with version and citation info." if options[:debug]


      # Update bill in ES
      puts "[#{bill_id}] Indexing bill in elasticsearch..." if options[:debug]

      Utils.es_batch!('bills', bill.bill_id,
        version_fields.merge(es_only).merge(updated_at: Time.now),
        batcher, options
      )


      # Run last version's XML through the processor into plain HTML, index in S3
      if version_fields[:last_version] and (version_fields[:last_version][:urls]['xml'])
        puts "[#{bill_id}] Processing XML into plain HTML using unitedstates/documents..." if options[:debug]
        bill_version_id = version_fields[:last_version][:bill_version_id]
        last_version_xml = "data/gpo/BILLS/#{congress}/#{type}/#{bill_version_id}.xml"

        begin
          last_version_html = UnitedStates::Documents::Bills.process File.read(last_version_xml)

          # cache the html on disk
          last_version_local = html_cache(congress, type, bill_version_id)
          Utils.write last_version_local, last_version_html
        rescue
          warnings << {message: "Error while processing XML->HTML for #{bill_version_id}"}
        end
      end

      puts "[#{bill_id}] Indexed." if options[:debug]

      bill_count += 1
    end

    # index any leftover docs
    Utils.es_flush! 'bills', batcher

    # sync extracted HTML to S3
    if options[:backup]
      backup_congress! congress, options
    end

    if warnings.any?
      Report.warning self, "Warnings found while parsing bill text and metadata", warnings: warnings
    end

    if gpo_missing.any?
      Report.note self, "GPO missing text for #{gpo_missing.size} bills", gpo_missing: gpo_missing
    end

    if notes.any?
      Report.note self, "Notes found while parsing bill text and metadata", notes: notes
    end

    Report.success self, "Loaded in full text of #{bill_count} bills (#{version_count} versions)."
  end

  def self.clean_text(text)
    # weird artifact at end
    text.gsub! '<all>', ''

    # remove unneeded whitespace
    text.gsub! "\n", " "
    text.gsub! "\t", " "
    text.gsub! /\s{2,}/, ' '

    # get rid of dumb smart quotes
    text.gsub! '``', '"'
    text.gsub! "''", '"'

    # remove underscore lines
    text.gsub! /_{2,}/, ''

    # de-hyphenate words broken up over multiple lines
    text.gsub!(/(\w)\-\s+(\w)/) {$1 + $2}

    text.strip
  end

  # expects the bill version's associated MODS XML
  def self.issued_on_for(doc)
    elem = doc.at("dateIssued")
    timestamp = elem ? elem.text : nil
    if timestamp.present?
      Utils.utc_parse(timestamp).strftime "%Y-%m-%d"
    else
      nil
    end
  end

  # expects the bill version's associated MODS XML
  def self.urls_for(doc)
    urls = {}

    (doc / "url").each do |elem|
      label = elem['displayLabel']
      if label =~ /HTML/i
        urls['html'] = elem.text
      elsif label =~ /XML/i
        urls['xml'] = elem.text
      elsif label =~ /PDF/i
        urls['pdf'] = elem.text
      end
    end

    urls
  end

  # expects the bill version's associated MODS XML
  def self.pages_for(doc)
    if extent = (doc / :physicalDescription / :extent).first
      extent.text.to_i
    end
  end

  def self.citation_cache(congress, bill_id)
    "data/citations/bills/#{congress}/#{bill_id}.json"
  end

  # todo: (?) move this out of data/citation
  def self.text_cache(congress, bill_id)
    "data/citations/bills/#{congress}/#{bill_id}.txt"
  end

  def self.html_cache(congress, bill_type, bill_version_id)
    "data/unitedstates/documents/bills/#{congress}/#{bill_type}/#{bill_version_id}.htm"
  end

  # bucket is set as unitedstates/documents/bills
  def self.html_remote(congress, bill_type, bill_version_id)
    "#{congress}/#{bill_type}/#{bill_version_id}.htm"
  end

  def self.backup_congress!(congress, options)
    Utils.backup!(:bills, "data/unitedstates/documents/bills/#{congress}", "#{congress}", {
      sync: true, silent: !options[:debug]
    })
  end

end