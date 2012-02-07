require 'nokogiri'
require 'curb'

class RegulationsFullText

  # options:
    # limit: limit it to a few, instead of all as-yet-unindexed regulations in the database
  def self.run(options = {})
    limit = options[:limit] ? options[:limit].to_i : nil
    regulation_id = options[:regulation_id]

    if options[:rearchive]
      Regulation.update_all :indexed => false
    end

    count = 0

    if regulation_id
      targets = Regulation.where :regulation_id => regulation_id
    else
      targets = Regulation.where :indexed => false
    end

    if limit
      targets = targets[0...limit]
    end

    client = Searchable.client_for 'regulations'

    missing_links = []

    targets.each do |regulation|

      id = regulation['regulation_id']
      doc = nil
      if regulation['full_text_xml_url']
        doc = doc_for :xml, id, regulation['full_text_xml_url'], options  
      elsif regulation['body_html_url']
        doc = doc_for :html, id, regulation['body_html_url'], options
      end

      return unless doc # warning will have been filed

      full_text = full_text_for doc, options

      fields = {}
      Regulation.basic_fields.each do |field|
        fields[field] = regulation[field.to_s]
      end
      fields[:full_text] = full_text

      puts "[#{regulation.regulation_id}] Indexing..."
      client.index fields, :id => regulation.regulation_id

      puts "\tMarking object as indexed..." if options[:debug]
      regulation['indexed'] = true
      regulation.save!

      count += 1
    end

    if missing_links.any?
      Report.warning self, "Missing #{missing_links.count} XML and HTML links for full text", :missing_links => missing_links
    end

    # make sure data is appearing now
    client.refresh

    Report.success self, "Indexed #{count} regulations as searchable"
  end

  def self.doc_for(type, regulation_id, url, options)
    begin
      puts "[#{regulation_id}] Fetching #{type.to_s.upcase} from FR.gov..." if options[:debug]
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