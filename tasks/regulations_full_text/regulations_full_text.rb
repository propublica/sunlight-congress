require 'nokogiri'
require 'curb'

class RegulationsFullText

  # Indexes full text of proposed and final regulations into ElasticSearch.
  # Takes any regulations in MongoDB that have not been marked as indexed, 
  # indexes them, and marks them so.

  # options:
  #   limit: limit it to a set number of, instead of all, unindexed regulations.
  #   document_number: index only a specific document.
  #   rearchive: mark everything as unindexed and re-index everything.
  #   rearchive_year: mark everything in a given year as unindexed and re-index everything.

  def self.run(options = {})
    limit = options[:limit] ? options[:limit].to_i : nil
    document_number = options[:document_number]

    # mark *everything* for rearchiving
    if options[:rearchive]
      Regulation.update_all :indexed => false
    end

    # mark only one year for rearchiving
    if options[:rearchive_year]
      Regulation.where(:year => options[:rearchive_year].to_i).update_all :indexed => false
    end

    count = 0

    if document_number
      targets = Regulation.where :document_number => document_number
    else
      targets = Regulation.where :indexed => false
    end

    if limit
      targets = targets[0...limit]
    end

    client = Searchable.client_for 'regulations'

    missing_links = []
    usc_warnings = []

    targets.each do |regulation|

      document_number = regulation['document_number']
      doc = nil

      if regulation['full_text_xml_url']
        doc = doc_for :xml, document_number, regulation['full_text_xml_url'], options  
      
      elsif regulation['body_html_url'] 
        doc = doc_for :html, document_number, regulation['body_html_url'], options

      else
        missing_links << document_number
      end

      next unless doc # warning will have been filed

      full_text = full_text_for doc, options

      # extract USC citations, place them on both elasticsearch and mongo objects
      usc_extracted_ids = []
      if usc_extracted = Utils.extract_usc(full_text)
        usc_extracted = usc_extracted.uniq # not keeping anything offset-specific
        usc_extracted_ids = usc_extracted.map {|r| r['usc']['id']}
      else
        usc_extracted = []
        usc_warnings << {:message => "Failed to extract USC from #{bill_version_id}"}
      end

      # temporary
      if usc_extracted_ids.any?
        puts "\t[#{document_number}] Found #{usc_extracted_ids.size} USC citations: #{usc_extracted_ids.inspect}" if options[:debug]
      end

      fields = {}
      Regulation.result_fields.each do |field|
        fields[field] = regulation[field.to_s]
      end
      fields[:full_text] = full_text
      fields[:usc_extracted] = usc_extracted
      fields[:usc_extracted_ids] = usc_extracted_ids

      puts "[#{regulation.document_number}] Indexing..."
      client.index fields, :id => regulation.document_number

      puts "\tMarking object as indexed..." if options[:debug]
      regulation['indexed'] = true
      regulation['usc_extracted'] = usc_extracted
      regulation['usc_extracted_ids'] = usc_extracted_ids
      regulation.save!

      count += 1
    end

    if missing_links.any?
      Report.warning self, "Missing #{missing_links.count} XML and HTML links for full text", :missing_links => missing_links
    end

    if usc_warnings.any?
      Report.warning self, "#{usc_warnings.size} warnings while extracting US Code citations", :usc_warnings => usc_warnings
    end

    # make sure data is appearing now
    client.refresh

    Report.success self, "Indexed #{count} regulations as searchable"
  end

  def self.doc_for(type, document_number, url, options)
    begin
      puts "[#{document_number}] Fetching #{type.to_s.upcase} from FR.gov..." if options[:debug]
      curl = Curl::Easy.new url
      curl.follow_location = true
      curl.perform
    rescue Timeout::Error, Errno::ECONNRESET, Errno::ETIMEDOUT, Errno::ENETUNREACH
      Report.warning self, "Timeout while polling FR.gov, aborting for now", :url => url
      return nil
    end

    if type == :xml
      Nokogiri::XML curl.body_str
    else
      Nokogiri::HTML curl.body_str
    end
  end

  def self.full_text_for(doc, options)
    strings = (doc/"//*/text()").map do |text| 
      text.inner_text.strip
    end.select {|text| text.present?}

    strings.join " "
  end

end