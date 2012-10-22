require 'httparty'

class RegulationsArchive

  # Downloads metadata about proposed and final regulations from FederalRegister.gov.
  # By default, grabs the last 7 days of both types of regulations.
  #
  # options:
  #   document_number: index a specific document only.
  #
  #   public_inspection: 
  #     if document_number is given, get the public_inspection version.
  #     if document_number is not given, fetch current public inspection documents.
  #
  #   year: 
  #     if month is given, is combined with month to index that specific month.
  #     if month is not given, indexes entire year's regulations (12 calls, one per month)
  #   month:
  #     if year is given, is combined with year to index that specific month.
  #     if year is not given, does nothing.
  #
  #   cache: use disk cache for requests to individual regulations
    
  def self.run(options = {})

    if options[:document_number]
      if options[:public_inspection]
        save_regulation! :public_inspection, options[:document_number], options
      else
        save_regulation! :article, options[:document_number], options
      end

    else

      ["PRORULE", "RULE"].each do |stage|
      
        if options[:year]
          year = options[:year].to_i
          months = options[:month] ? [options[:month].to_i] : (1..12).to_a.reverse
          
          months.each do |month|
            beginning = Time.parse("#{year}-#{month}-01")
            ending = (beginning + 1.month) - 1.day
            load_regulations stage, beginning, ending, options
          end

        else
          # default to last 7 days
          ending = Time.now.midnight
          beginning = ending - 7.days
          load_regulations stage, beginning, ending, options
        end

      end

      # load current day's public inspections
      load_public_inspections options
    end
  end

  def self.load_public_inspections(options)
    base_url = "http://api.federalregister.gov/v1/public-inspection-documents/current.json"
    base_url << "?fields[]=document_number&fields[]=type"

    puts "Fetching current public inspection documents..." if options[:debug]

    unless response = Utils.download(base_url, options.merge(json: true))
      Report.warning self, "Error while polling FR.gov (#{base_url}), aborting for now", url: base_url
      return
    end

    if response['errors']
      Report.error self, "Errors, not sure what this looks like...", errors: response['errors']
      return
    end

    if response['count'] >= 1000
      Report.warning self, "Likely more than 1000 public inspection docs today, that is crazy"
      # continue on
    end

    count = 0

    response['results'].each do |article|
      document_number = article['document_number']
      
      # the current.json endpoint can't also be filtered by type, so we'll filter client-side
      if ["proposed rule", "rule"].include?(article['type'].downcase)
        if save_regulation!(:public_inspection, document_number, options)
          count += 1
        end
      else
        # puts "Skipping non-rule PI doc..." if options[:debug]
      end
    end

    Report.success self, "Added #{count} current RULE and PRORULE public inspection docs"
  end


  def self.load_regulations(stage, beginning, ending, options)
    base_url = "http://api.federalregister.gov/v1/articles.json"
    base_url << "?conditions[type]=#{stage}"
    base_url << "&conditions[publication_date][lte]=#{ending.strftime "%m/%d/%Y"}"
    base_url << "&conditions[publication_date][gte]=#{beginning.strftime "%m/%d/%Y"}"
    base_url << "&fields[]=document_number"
    base_url << "&per_page=1000"

    puts "Fetching #{stage} regulations from #{beginning.strftime "%m/%d/%Y"} to #{ending.strftime "%m/%d/%Y"}..."
    
    # the API serves a max of 1000 documents, no matter how it's paginated
    # fetch a page of 1000 documents
    # - this should be enough to not miss anything if filtered by month and stage, 
    #   but if not, catch it
    
    unless response = Utils.download(base_url, options.merge(json: true))
      Report.warning self, "Error while polling FR.gov (#{base_url}), aborting for now", url: base_url
      return
    end

    if response['errors']
      Report.error self, "Errors, not sure what this looks like...", errors: response['errors']
      return
    end

    if response['count'] >= 1000
      Report.warning self, "Likely more than 1000 #{stage} regulations between #{ending} and #{beginning}"
      # continue on
    end

    count = 0

    # not an error, just means there's no results in this timeframe (like for future months)
    unless response['results']
      puts "No results for this time frame" if options[:debug]
      return
    end

    response['results'].each do |article|
      document_number = article['document_number']
      
      if rule = save_regulation!(:article, document_number, options)
        count += 1
      end
    end

    Report.success self, "Added #{count} #{stage} regulations from FederalRegister.gov"
  end


  # save a PI doc or regulation into mongo

  def self.save_regulation!(document_type, document_number, options)
    puts "\n[#{document_type}][#{document_number}] Fetching rule..." if options[:debug]

    url = details_url_for document_type, document_number
    destination = destination_for document_type, document_number, "json"

    unless details = Utils.download(url, options.merge(destination: destination, json: true))
      Report.warning self, "Error while polling FR.gov for article details at #{url}, skipping article", url: url
      return
    end

    rule = Regulation.find_or_initialize_by document_number: document_number

    if !rule.new_record? and (document_type == :public_inspection) and (rule['document_type'] != "public_inspection")
      puts "\tNot storing public inspection, document already released..." if options[:debug]
      return
    end

    if !rule.new_record? and (document_type == :article) and (rule['document_type'] != "article")
      puts "\tArticle replacing public inspection document, wiping fields..." if options[:debug]
      rule.destroy
      rule = Regulation.new document_number: document_number
    end

    # turn Dates into Times
    ['publication_date', 'comments_close_on', 'effective_on', 'signing_date'].each do |field|
      # one other field is 'dates', and I don't know what the possible values are for that yet
      if details[field]
        details[field] = Utils.noon_utc_for details[field].to_time
      end
    end

    # Since we're using the Yajl parser, we need to parse timestamps ourselves
    ['filed_at', 'pdf_updated_at'].each do |field|
      if details[field]
        details[field] = Utils.utc_parse details[field]
      end
    end

    # maps FR document type to rule stage
    type_to_stage = {
      "Proposed Rule" => "proposed",
      "Rule" => "final"
    }

    # common to public inspection documents and to articles
    attributes = {
      stage: type_to_stage[details['type']],
      agency_names: details['agencies'].map {|agency| agency['name'] || agency['raw_name']},
      agency_ids: details['agencies'].map {|agency| agency['id']},
      publication_date: details['publication_date'],

      federal_register_url: details['html_url'],
      federal_register_json_url: url,
      pdf_url: details['pdf_url'],

      document_type: document_type.to_s
    }

    if document_type == :article
      attributes.merge!(
        title: details['title'],
        abstract: details['abstract'],
        effective_at: details['effective_on'],
        full_text_xml_url: details['full_text_xml_url'],
        body_html_url: details['body_html_url'],

        # for articles, main timestamp is based on publication_date
        published_at: details['publication_date'],
        year: details['publication_date'].year,

        rins: details['regulation_id_numbers'],
        docket_ids: details['docket_ids']
      )

    elsif document_type == :public_inspection
      # The title field can sometimes be blank, in which case it can be cobbled together.
      # According to FR.gov team, this produces the final title 95% of the time.
      # They aren't comfortable with calling it the 'title' - but I think I am.
      title = nil
      if details['title'].present?
        title = details['title']
      elsif details['toc_subject'].present? and details['toc_doc'].present?
        title = [details['toc_subject'], details['toc_doc']].join(" ")
      end

      attributes.merge!(
        title: title,
        num_pages: details['num_pages'],
        pdf_updated_at: details['pdf_updated_at'],
        raw_text_url: details['raw_text_url'],
        filed_at: details['filed_at'],

        # different key name for PI docs for some reason
        docket_ids: details['docket_numbers'],
        
        # for PI docs, main timestamp is based on filing date
        published_at: details['filed_at'],
        year: details['filed_at'].year
      )
    end

    puts "[#{document_number}] Saving..."
    rule.attributes = attributes
    rule.save!

    rule
  end


  def self.text_for(document_type, document_number, format, url, options)
    destination = destination_for document_type, document_number, format
    
    unless Utils.download(url, options.merge(destination: destination))
      Report.warning self, "Error while polling FR.gov, aborting for now", url: url
      return nil
    end


    body = File.read destination

    if format == :xml
      text = full_text_for Nokogiri::XML(body)
      text_destination = destination_for document_type, document_number, :txt
      Utils.write text_destination, text
      text
    elsif format == :html
      text = full_text_for Nokogiri::HTML(body)
      text_destination = destination_for document_type, document_number, :txt
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


  # urls/directories

  def self.details_url_for(document_type, document_number)
    endpoint = {article: "articles", public_inspection: "public-inspection-documents"}[document_type]
    "http://api.federalregister.gov/v1/#{endpoint}/#{document_number}.json"
  end

  def self.destination_for(document_type, document_number, format)
    yearish = document_number.split("-").first
    "data/federalregister/#{yearish}/#{document_number}/#{document_type}.#{format}"
  end

  def self.citation_cache(document_number)
    RegulationsArchive.destination_for "citation", document_number, "json"
  end
end