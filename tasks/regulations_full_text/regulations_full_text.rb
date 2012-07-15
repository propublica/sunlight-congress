require 'nokogiri'
require 'curb'

require './tasks/regulations_archive/regulations_archive'

class RegulationsFullText

  # Indexes full text of proposed and final regulations into ElasticSearch.
  # Takes any regulations in MongoDB that have not been marked as indexed, 
  # indexes them, and marks them so.

  # options:
  #   limit: limit it to a set number of, instead of all, unindexed regulations.
  #   document_number: index only a specific document.
  #   document_type: only a certain type of document (article, public_inspection)
  #
  #   rearchive: mark everything as unindexed and re-index everything.
  #   rearchive_year: mark everything in a given year as unindexed and re-index everything.
  #   redownload: ignore cached files

  def self.run(options = {})
    limit = options[:limit] ? options[:limit].to_i : nil
    document_number = options[:document_number]

    if options[:rearchive]
      Regulation.update_all indexed: false
    end

    # mark only one year for rearchiving
    if options[:rearchive_year]
      Regulation.where(year: options[:rearchive_year].to_i).update_all indexed: false
    end

    count = 0

    if document_number
      targets = Regulation.where document_number: document_number
    else
      targets = Regulation.where indexed: false
      
      if options[:document_type]
        targets = targets.where document_type: options[:document_type]
      end
    end

    if limit
      targets = targets[0...limit]
    end

    missing_links = []
    usc_warnings = []

    targets.each do |regulation|

      document_number = regulation['document_number']

      full_text = nil

      if regulation['document_type'] == 'article'
        if regulation['full_text_xml_url']
          full_text = text_for :article, document_number, :xml, regulation['full_text_xml_url'], options
          
        elsif regulation['body_html_url'] 
          full_text = text_for :article, document_number, :html, regulation['body_html_url'], options

        else
          missing_links << document_number
        end
      else
        if regulation['raw_text_url']
          full_text = text_for :public_inspection, document_number, :txt, regulation['raw_text_url'], options
        else
          missing_links << document_number
        end
      end

      next unless full_text # warning will have been filed

      # extract USC citations, place them on both elasticsearch and mongo objects
      # usc_extracted_ids = []
      # if usc_extracted = Utils.extract_usc(full_text)
      #   usc_extracted = usc_extracted.uniq # not keeping anything offset-specific
      #   usc_extracted_ids = usc_extracted.map {|r| r['usc']['id']}
      # else
      #   usc_extracted = []
      #   usc_warnings << {message: "Failed to extract USC from #{document_number}"}
      # end

      # temporary
      # if usc_extracted_ids.any?
      #   puts "\t[#{document_number}] Found #{usc_extracted_ids.size} USC citations: #{usc_extracted_ids.inspect}" if options[:debug]
      # end

      # load in the part of the regulation from mongo that gets synced to ES
      fields = {}
      Regulation.result_fields.each do |field|
        fields[field] = regulation[field.to_s]
      end

      # index into elasticsearch
      puts "[#{regulation.document_number}] Indexing..."
      fields['full_text'] = full_text
      # fields['usc_extracted'] = usc_extracted
      # fields['usc_extracted_ids'] = usc_extracted_ids
      Utils.es_store! 'regulations', regulation.document_number, fields

      # update in mongo
      puts "\tMarking object as indexed and adding any extracted citations..." if options[:debug]
      regulation['indexed'] = true
      # regulation['usc_extracted'] = usc_extracted
      # regulation['usc_extracted_ids'] = usc_extracted_ids
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
    Utils.es_refresh! 'regulations'

    Report.success self, "Indexed #{count} regulations as searchable"
  end

  def self.text_for(document_type, document_number, format, url, options)
    destination = RegulationsArchive.destination_for document_type, document_number, format

    body = nil
    # use cache if it exists, unless 
    if File.exists?(destination) and options[:redownload].blank?
      puts "[#{document_number}] Using cached #{format.to_s.upcase} from FR.gov" if options[:debug]
      # don't fetch, it's here

    else
      puts "[#{document_number}] Fetching #{format.to_s.upcase} from FR.gov..." if options[:debug]
      unless Utils.curl(url, destination)
        Report.warning self, "Error while polling FR.gov, aborting for now", :url => url
        return nil
      end

    end

    body = File.read destination

    if format == :xml
      text = full_text_for Nokogiri::XML(body)
      text_destination = RegulationsArchive.destination_for document_type, document_number, :txt
      Utils.write text_destination, text
      text
    elsif format == :html
      text = full_text_for Nokogiri::HTML(body)
      text_destination = RegulationsArchive.destination_for document_type, document_number, :txt
      Utils.write text_destination, text
      text
    else # text, it's done
      pi_text_for body
    end
  end

  def self.full_text_for(doc)
    return nil unless doc

    strings = (doc/"//*/text()").map do |text| 
      text.inner_text.strip
    end.select {|text| text.present?}

    strings.join " "
  end

  def self.pi_text_for(body)
    body.gsub /[\n\r]/, ' '
  end

end