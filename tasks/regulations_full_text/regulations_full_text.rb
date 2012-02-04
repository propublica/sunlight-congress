require 'nokogiri'
require 'curb'

class RegulationsFullText

  # options:
    # limit: limit it to a few, instead of all as-yet-unindexed regulations in the database
  def self.run(options = {})
    limit = options[:limit] ? options[:limit].to_i : nil
    regulation_id = options[:regulation_id]

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

    targets.each do |regulation|

      doc = full_xml_doc_for regulation, options
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

    # make sure data is appearing now
    client.refresh

    Report.success self, "Indexed #{count} regulations as searchable"
  end

  def self.full_xml_doc_for(regulation, options)
    begin
      puts "[#{regulation['regulation_id']}] Fetching XML from FR.gov..." if options[:debug]
      curl = Curl::Easy.new regulation['full_text_xml_url']
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