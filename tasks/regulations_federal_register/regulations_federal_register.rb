require 'httparty'

class RegulationsFederalRegister

  # options:
    
  def self.run(options = {})
    # stage = options[:stage] ? options[:stage].to_sym : nil

    all_stages = {
      :proposed => "PRORULE",
      :final => "RULE"
    }

    if options[:document_number]
      save_regulation! options[:document_number], options
    else

      all_stages.values.each do |stage|
      
        if options[:year]
          year = options[:year].to_i
          months = options[:month] ? [options[:month].to_i] : (1..12).to_a
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
    end
  end

  def self.load_regulations(stage, beginning, ending, options)
    base_url = "http://api.federalregister.gov/v1/articles.json?"
    base_url << "conditions[type]=#{stage}"
    base_url << "&conditions[publication_date][lte]=#{ending.strftime "%m/%d/%Y"}"
    base_url << "&conditions[publication_date][gte]=#{beginning.strftime "%m/%d/%Y"}"

    puts "Fetching #{stage} regulations from #{beginning.strftime "%m/%d/%Y"} to #{ending.strftime "%m/%d/%Y"}..."
    
    if pages = total_pages_for(base_url, options)
      puts "Archiving, going to fetch #{pages} pages of data"
    else
      # already filed warning Report in method
      return
    end

    count = 0
    
    pages.times do |i|
      i += 1 # 1-indexed, please
      page_url = "#{base_url}&page=#{i}"

      begin
        puts "Fetching page #{i}..." if options[:debug]
        response = HTTParty.get page_url
      rescue Timeout::Error => ex
        Report.warning self, "Timeout while polling FR.gov, aborting for now", :url => page_url
        return
      end

      if response['errors']
        Report.error self, "Errors, not sure what this looks like...", :errors => response['errors']
        return
      end

      response['results'].each do |article|
        document_number = article['document_number']
        
        save_regulation! document_number, options

        count += 1
      end

      # don't hammer, if there are more pages to go
      sleep 1 unless i == pages
    end

    Report.success self, "Added #{count} #{stage} rules from FederalRegister.gov"
  end

  def self.save_regulation!(document_number, options)
    rule = Regulation.find_or_initialize_by :document_number => document_number
      
    begin
      url = "http://api.federalregister.gov/v1/articles/#{document_number}.json"
      details = HTTParty.get url
    rescue Timeout::Error => ex
      Report.warning self, "Timeout while polling FR.gov for article details, skipping article", :url => article['json_url']
      next
    end

    # turn Dates into Times
    ['publication_date', 'comments_close_on', 'effective_on'].each do |field|
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
      :stage => type_to_stage[details['type']],
      :published_at => details['publication_date'],
      :abstract => details['abstract'],
      :title => details['title'],
      :federal_register_url => details['html_url'],
      :agency_names => details['agencies'].map {|agency| agency['name']},
      :agency_ids => details['agencies'].map {|agency| agency['id']},
      :effective_at => details['effective_on'],
      :full_text_xml_url => details['full_text_xml_url'],
      :body_html_url => details['body_html_url'],

      :rins => details['regulation_id_numbers'],
      :docket_ids => details['docket_ids']
    }

    if rule.new_record?
      rule[:indexed] = false
    end

    # lump the rest into a catch-all
    rule[:federal_register] = details.to_hash

    rule.save!
    puts "[#{document_number}] Saved rule to database" if options[:debug]
  end

  def self.total_pages_for(base_url, options)
    begin
      puts "Fetching first page to find total_pages..." if options[:debug]
      response = HTTParty.get base_url
    rescue Timeout::Error => ex
      Report.warning self, "Timeout while polling FR.gov, aborting for now", :url => base_url
      return nil
    end

    response['total_pages']
  end
end