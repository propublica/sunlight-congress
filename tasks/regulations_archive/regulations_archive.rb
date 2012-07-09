require 'httparty'

class RegulationsArchive

  # Downloads metadata about proposed and final regulations from FederalRegister.gov.
  # By default, grabs the last 7 days of both types of regulations.
  # Does not index full text.

  # options:
  #   document_number: index a specific document only.
  #   year: 
  #     if month is given, is combined with month to index that specific month.
  #     if month is not given, indexes entire year's regulations (12 calls, one per month)
  #   month:
  #     if year is given, is combined with year to index that specific month.
  #     if year is not given, does nothing.
  #
  #   redownload: force a redownload of JSON files for individual documents
    
  def self.run(options = {})

    if options[:document_number]
      save_regulation! :article, options[:document_number], options
    else

      ["PRORULE", "RULE"].each do |stage|
      
        if options[:year]
          year = options[:year].to_i
          months = options[:month] ? [options[:month].to_i] : (1..12).to_a
          
          months.each do |month|
            beginning = Time.parse("#{year}-#{month}-01")
            ending = (beginning + 1.month) - 1.day
            load_regulations :article, stage, beginning, ending, options
          end

          # need do the cycle over again, to avoid awkardness where PI doc 
          # comes on last day of month, and its replacement in the next month
          # months.each do |month|
          #   beginning = Time.parse("#{year}-#{month}-01")
          #   ending = (beginning + 1.month) - 1.day
          #   load_regulations :public_inspection, stage, beginning, ending, options
          # end

        else
          # default to last 7 days
          ending = Time.now.midnight
          beginning = ending - 7.days
          load_regulations :article, stage, beginning, ending, options
        end

      end
    end
  end

  def self.load_regulations(document_type, stage, beginning, ending, options)
    endpoint = {article: "articles", public_inspection: "public"}[document_type]

    base_url = "http://api.federalregister.gov/v1/#{endpoint}.json?"
    base_url << "conditions[type]=#{stage}"
    base_url << "&conditions[publication_date][lte]=#{ending.strftime "%m/%d/%Y"}"
    base_url << "&conditions[publication_date][gte]=#{beginning.strftime "%m/%d/%Y"}"
    base_url << "&fields[]=document_number"
    base_url << "&per_page=1000"

    puts "Fetching #{stage} regulations from #{beginning.strftime "%m/%d/%Y"} to #{ending.strftime "%m/%d/%Y"}..."
    
    # the API serves a max of 1000 documents, no matter how it's paginated
    # fetch a page of 1000 documents
    # - this should be enough to not miss anything if filtered by month and stage, 
    #   but if not, catch it
    
    unless response = Utils.json_for(base_url)
      Report.warning self, "Error while polling FR.gov (#{base_url}), aborting for now", url: base_url
      return
    end

    if response['errors']
      Report.error self, "Errors, not sure what this looks like...", errors: response['errors']
      return
    end

    puts "page count: #{response['count']}"
    if response['count'] >= 1000
      Report.warning self, "Likely more than 1000 #{stage} regulations between #{ending} and #{beginning}"
      # continue on
    end

    count = 0

    response['results'].each do |article|
      document_number = article['document_number']
      
      if save_regulation!(:article, document_number, options)
        count += 1
      end
    end

    Report.success self, "Added #{count} #{stage} #{endpoint} from FederalRegister.gov"
  end

  def self.save_regulation!(document_type, document_number, options)
    puts "[#{document_type}][#{document_number}] Fetching rule..." if options[:debug]

    endpoint = {article: "articles", public_inspection: "public"}[document_type]
    url = "http://api.federalregister.gov/v1/#{endpoint}/#{document_number}.json"
    destination = destination_for document_type, document_number, "json"

    details = json_for url, destination, options

    rule = Regulation.find_or_initialize_by document_number: document_number

    # turn Dates into Times
    ['publication_date', 'comments_close_on', 'effective_on', 'signing_date'].each do |field|
      # one other field is 'dates', and I don't know what the possible values are for that yet
      if details[field]
        details[field] = Utils.noon_utc_for details[field].to_time
      end
    end

    # maps FR document type to rule stage
    type_to_stage = {
      "Proposed Rule" => "proposed",
      "Rule" => "final"
    }

    rule.attributes = {
      stage: type_to_stage[details['type']],
      published_at: details['publication_date'],
      year: details['publication_date'].year,
      abstract: details['abstract'],
      title: details['title'],
      federal_register_url: details['html_url'],
      federal_register_json_url: url,
      agency_names: details['agencies'].map {|agency| agency['name']},
      agency_ids: details['agencies'].map {|agency| agency['id']},
      effective_at: details['effective_on'],
      full_text_xml_url: details['full_text_xml_url'],
      body_html_url: details['body_html_url'],

      rins: details['regulation_id_numbers'],
      docket_ids: details['docket_ids']
    }

    if rule.new_record?
      rule[:indexed] = false
    end

    # lump the rest into a catch-all
    rule[:federal_register] = details.to_hash

    begin
      rule.save!
    rescue BSON::InvalidDocument => ex
      Report.failure self, "BSON date exception, trying to save the following hash:\n\n#{JSON.pretty_generate attrs}"
      raise ex # re-raise after filing report, crash the task
    end

    true
  end

  def self.json_for(url, destination, options)
    if File.exists?(destination) and options[:redownload].blank?
      puts "\tCached, not downloading" if options[:debug]
      return Yajl::Parser.parse(open(destination))
    else
      puts "\tNot cached, downloading" if options[:debug]
    end
  
    if details = Utils.json_for(url, destination)
      details
    else
      Report.warning self, "Error while polling FR.gov for article details at #{url}, skipping article", url: url
      return
    end
  end

  def self.destination_for(document_type, document_number, format)
    yearish = document_number.split("-").first
    "data/federalregister/#{yearish}/#{document_number}/#{document_type}.#{format}"
  end
end