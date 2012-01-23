require 'httparty'

class RegulationsFederalRegister

  # options:
    # pages: number of pages to get (defaults to just 1 - as of right now, 50 is enough to archive it all.)
  def self.run(options = {})
    stage = options[:stage] ? options[:stage].to_sym : :proposed

    stages = {
      :proposed => "PRORULE",
      :final => "RULE"
    }

    base_url = "http://api.federalregister.gov/v1/articles.json?conditions[type]=#{stages[stage]}"
  

    if options[:archive]
      if pages = total_pages_for(base_url, options)
        puts "Archiving, going to fetch #{pages} pages of data"
      else
        # already filed warning Report in method
        return
      end
    else
      pages = 1
    end

    count = 0
    
    pages.times do |i|
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
        fr_id = article['document_number']
        rule = Regulation.find_or_initialize_by :regulation_id => "#{fr_id}-#{stage}"
          
        begin
          details = HTTParty.get article['json_url']
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

        rule.attributes = {
          :fr_id => fr_id,
          :stage => stage,
          :published_at => details['publication_date'],
          :abstract => details['abstract'],
          :title => details['title'],
          :federal_register_url => details['html_url'],
          :agency_names => details['agencies'].map {|agency| agency['name']},
          :agency_ids => details['agencies'].map {|agency| agency['id']},
          :effective_at => details['effective_on'],

          :rins => details['regulation_id_numbers'],
          :docket_ids => details['docket_ids']
        }

        # lump the rest into a catch-all
        rule[:federal_register] = details.to_hash

        rule.save!
        puts "[#{fr_id}] Saved rule to database" if options[:debug]
        count += 1
      end

      # don't hammer, if there are more pages to go
      sleep 1 unless i == pages
    end

    Report.success self, "Added #{count} #{stage} rules from FederalRegister.gov"
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