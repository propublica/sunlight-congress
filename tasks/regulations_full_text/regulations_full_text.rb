require 'nokogiri'
require 'curb'

class RegulationsFullText

  # options:
    # limit: limit it to a few, instead of all as-yet-unindexed regulations in the database
    # document_number: limit it to a specific document_number
    # rearchive: re-index everything, whether it's been marked as indexed or not
  def self.run(options = {})
    limit = options[:limit] ? options[:limit].to_i : nil
    document_number = options[:document_number]

    if options[:rearchive]
      Regulation.update_all :indexed => false
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

    targets.each do |regulation|

      document_number = regulation['document_number']
      doc = nil
      if regulation['full_text_xml_url']
        doc = doc_for :xml, document_number, regulation['full_text_xml_url'], options  
      else
        missing_links << document_number
      end

      next unless doc # warning will have been filed

      full_text = full_text_for doc, options

      fields = {}
      Regulation.basic_fields.each do |field|
        fields[field] = regulation[field.to_s]
      end
      fields[:full_text] = full_text

      puts "[#{regulation.document_number}] Indexing..."
      client.index fields, :id => regulation.document_number

      puts "\tMarking object as indexed..." if options[:debug]
      regulation['indexed'] = true
      regulation.save!

      count += 1
    end

    if missing_links.any?
      Report.warning self, "Missing #{missing_links.count} XML links for full text", :missing_links => missing_links
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
      Report.warning self, "Timeout while polling FR.gov, aborting for now", :url => base_url
      return nil
    end

    Nokogiri::XML curl.body_str
  end

  def self.full_text_for(doc, options)
    strings = (doc/"//*/text()").map do |text| 
      text.inner_text.strip
    end.select {|text| text.present?}

    strings.join " "
  end

end