require 'us-documents'

class Regulations

  # Downloads metadata about proposed and final regulations from FederalRegister.gov.
  # By default, grabs the last 7 days of both types of regulations.
  #
  # options:
  #   document_number: index a specific document only.
  #
  #   article_type: limit documents to a particular article_type (rule, prorule, notice).
  #     does not apply to public inspection documents.
  #
  #   public_inspection:
  #     if document_number is not given, fetch all current public inspection documents.
  #     if document_number is given, get the public_inspection version.
  #
  #   year:
  #     if month is given, is combined with month to index that specific month.
  #     if month is not given, indexes entire year's regulations (12 calls, one per month)
  #   month:
  #     if year is given, is combined with year to index that specific month.
  #     if year is not given, does nothing.
  #
  #   days:
  #     if year is given, does nothing.
  #     if year is not given, fetches last N days of regulations. (Defaults to 7.)
  #
  #   limit: limit processing to N documents
  #
  #   cache:
  #     cache requests for detail JSON on individual documents
  #     will not cache search requests, is safe to turn on for syncing new documents
  #
  #   cache_lists:
  #     cache search requests, useful for debugging
  #
  #   skip_text: do not do full text processing (mongo only)

  #  Hierarchy of regulatory documents:
  #    All documents:
  #      document_type: "article", "public_inspection"
  #      article_type: "regulation", "notice"
  #
  #    For article_type "regulation":
  #      stage: "proposed", "final"

  def self.run(options = {})
    document_type = options[:public_inspection] ? :public_inspection : :article

    if options[:article_type]
      article_types = [options[:article_type].upcase]
    else
      article_types = ["PRORULE", "RULE", "NOTICE"]
    end


    warnings = []
    missing_links = []
    citation_warnings = []
    batcher = [] # ES batcher


    # single regulation
    if options[:document_number]
      targets = [options[:document_number]]

    # load current day's public inspections
    elsif document_type == :public_inspection
      targets = pi_docs_for options, warnings

    # proposed and final regulations
    elsif document_type == :article
      targets = []

      article_types.each do |type|

        # a whole month or year
        if options[:year]
          year = options[:year].to_i
          months = options[:month] ? [options[:month].to_i] : (1..12).to_a.reverse

          months.each do |month|

            # break it up by week
            beginning = Time.parse("#{year}-#{month}-01")

            # 5 weeks, there will be inefficient overlap, oh well
            5.times do |i|
              ending = (beginning + 6.days) # 7 day window
              targets += regulations_for type, beginning, ending, options, warnings
              beginning += 7.days # advance counter by a week
            end
          end

        # default to last 7 days
        else
          days = options[:days] ? options[:days].to_i : 7
          ending = Time.now.midnight # only yyyy-mm-dd is used, time of day doesn't matter
          beginning = ending - days.days
          targets += regulations_for type, beginning, ending, options, warnings
        end

      end
    end

    targets = targets.uniq # 5-week window may cause dupes

    if options[:limit]
      targets = targets.first options[:limit].to_i
    end

    count = 0
    search_count = 0

    targets.each do |document_number|

      puts "\n[#{document_type}][#{document_number}] Fetching article..." if options[:debug]
      url = details_url_for document_type, document_number
      destination = destination_for document_type, document_number, "json"

      unless details = Utils.download(url, options.merge(destination: destination, json: true))
        warnings << {message: "Error while polling FR.gov for article details at #{url}, skipping article", url: url}
        next
      end

      rule = Regulation.find_or_initialize_by document_number: document_number

      if !rule.new_record? and (document_type == :public_inspection) and (rule['document_type'] != "public_inspection")
        puts "\tNot storing public inspection, document already released..." if options[:debug]
        next
      end

      if !rule.new_record? and (document_type == :article) and (rule['document_type'] != "article")
        puts "\tArticle replacing public inspection document, wiping fields..." if options[:debug]
        rule.destroy
        rule = Regulation.new document_number: document_number
      end

      pdf_url = details['pdf_url']
      pdf_url = nil if pdf_url == "missing.pdf"

      # common to public inspection documents and to articles
      attributes = {
        document_type: document_type.to_s,

        agency_names: details['agencies'].map {|agency| agency['name'] || agency['raw_name']},
        agency_ids: details['agencies'].map {|agency| agency['id']},
        publication_date: details['publication_date'],

        url: details['html_url'],
        pdf_url: pdf_url
      }

      # maps FR document type to rule stage
      type_to_stage = {
        "Proposed Rule" => "proposed",
        "Rule" => "final"
      }

      if stage = type_to_stage[details['type']]
        attributes[:article_type] = "regulation"
        attributes[:stage] = stage

      else # notices
        attributes[:article_type] = details['type'].downcase
      end


      if document_type == :article
        attributes.merge!(
          title: details['title'],
          docket_ids: details['docket_ids'],
          posted_at: noon_utc_for(details['publication_date']),

          abstract: details['abstract'],
          effective_on: details['effective_on'],
          rins: details['regulation_id_numbers'],
          comments_close_on: details['comments_close_on'],

          abstract_html_url: details['abstract_html_url'],
          body_html_url: details['body_html_url']
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
          docket_ids: details['docket_numbers'],
          posted_at: Utils.utc_parse(details['filed_at'])
        )
      end

      # save the mongo document
      puts "[#{document_number}] Saving to MongoDB..." if options[:debug]
      rule.attributes = attributes
      rule.save!
      count += 1

      next if options[:skip_text]

      puts "[#{document_number}] Fetching full text..." if options[:debug]

      full_text = nil

      if document_type == :article
        if details['body_html_url']
          full_text = text_for :article, document_number, :html, details['body_html_url'], options

          # take the opportunity to just download abstract, if it exists
          if details['abstract_html_url']
            text_for :article_abstract, document_number, :html, details['abstract_html_url'], options
          end

        else
          missing_links << document_number
        end
      else
        if details['raw_text_url']
          full_text = text_for :public_inspection, document_number, :txt, details['raw_text_url'], options
        else
          missing_links << document_number
        end
      end

      unless full_text
        warnings << {message: "Error while polling FR.gov, aborting for now", url: url}
        puts "[#{document_number}] No full text to index, moving on..."
        next
      end


      unless citation_ids = Utils.citations_for(rule, full_text, citation_cache(document_number), options)
        citation_warnings << {message: "Failed to extract citations from #{document_number}"}
        citation_ids = []
      end

      # load in the part of the regulation from mongo that gets synced to ES
      fields = {}
      Regulation.basic_fields.each do |field|
        fields[field] = rule[field.to_s]
      end

      # index into elasticsearch
      puts "[#{document_number}] Indexing text of regulation..." if options[:debug]
      fields['text'] = full_text
      fields['citation_ids'] = citation_ids

      Utils.es_batch! 'regulations', document_number, fields, batcher, options

      # re-save Mongo record with citation IDs
      rule['citation_ids'] = citation_ids
      rule.save!

      # for published docs, download the abstract and body html,
      # save to disk, backup in S3 if asked
      if document_type != :public_inspection
        html_document! rule, warnings, options
      end

      search_count += 1
    end

    # index any leftover docs
    Utils.es_flush! 'regulations', batcher


    if warnings.any?
      Report.warning self, "#{warnings.size} warnings", warnings: warnings
    end

    if missing_links.any?
      Report.warning self, "Missing #{missing_links.count} XML and HTML links for full text", missing_links: missing_links
    end

    if citation_warnings.any?
      Report.warning self, "#{citation_warnings.size} warnings while extracting citations", citation_warnings: citation_warnings
    end

    if document_type == :article
      Report.success self, "Processed #{count} #{article_types.join ", "} regulations"
    elsif document_type == :public_inspection
      Report.success self, "Processed #{count} current RULE, PRORULE, and NOTICE public inspection docs"
    end

    Report.success self, "Indexed #{search_count} documents as searchable"
  end


  # for published documents only
  def self.html_document!(document, warnings, options = {})
    puts "[#{document['document_number']}] Transforming HTML using unitedstates/documents..." if options[:debug]

    # join abstract and body html together into one document, if both exist
    # abstract and body html will already have been downloaded
    html = ""

    begin
      abstract_cache = destination_for :article_abstract, document['document_number'], "html"
      if File.exists?(abstract_cache)
        abstract = File.read abstract_cache
        html << UnitedStates::Documents::FederalRegister.process(abstract, class: "abstract")
      end

      body_cache = destination_for :article, document['document_number'], "html"
      if File.exists?(body_cache)
        body = File.read body_cache
        html << UnitedStates::Documents::FederalRegister.process(body, class: "body")
      end
    rescue Exception => ex
      warnings << {message: "Error while processing HTML for #{document['document_number']}", exception: ex.message, name: ex.class.to_s}
    end

    document_number = document['document_number']

    html_local = html_cache document_number
    html_remote = html_remote document_number
    html_backed = html_local + ".backed"

    Utils.write html_local, html
    puts "[#{document_number}] Wrote HTML to disk."

    if options[:backup]
      if !File.exists?(html_backed)
        Utils.write html_backed, Time.now.to_i.to_s
        Utils.backup! :regulations,
          html_local, html_remote,
          silent: !options[:debug]
        puts "[#{document_number}] Uploaded HTML to S3."
      else
        puts "[#{document_number}] Already uploaded to S3."
      end
    end



    true
  end


  # document numbers for current PI docs

  def self.pi_docs_for(options, warnings)
    base_url = "https://www.federalregister.gov/api/v1/public-inspection-documents/current.json"
    base_url << "?fields[]=document_number&fields[]=type"

    puts "Fetching current public inspection documents..." if options[:debug]

    unless response = Utils.download(base_url, options.merge(json: true))
      warnings << {msg: "Error while polling FR.gov (#{base_url}), aborting for now", url: base_url}
      return []
    end

    if response['errors']
      Report.error self, "Errors, not sure what this looks like...", errors: response['errors']
      return []
    end

    unless response['count']
      Report.exception self, "No count field?", response: response.to_s
      return []
    end

    if response['count'] >= 1000
      Report.warning self, "Likely more than 1000 public inspection docs today, that is crazy"
      # continue on
    end

    response['results'].map do |article|
      # the current.json endpoint can't also be filtered by type, so we'll filter client-side
      if ["proposed rule", "rule"].include?(article['type'].downcase)
        article['document_number']
      else
        puts "Skipping non-rule PI doc..." if options[:debug]
        nil
      end
    end.compact
  end


  # document numbers for published regs in the given range

  def self.regulations_for(type, beginning, ending, options, warnings)
    base_url = "https://www.federalregister.gov/api/v1/articles.json"
    base_url << "?conditions[type]=#{type}"
    base_url << "&conditions[publication_date][lte]=#{ending.strftime "%m/%d/%Y"}"
    base_url << "&conditions[publication_date][gte]=#{beginning.strftime "%m/%d/%Y"}"
    base_url << "&fields[]=document_number"
    base_url << "&per_page=1000"

    puts "Fetching #{type} articles from #{beginning.strftime "%m/%d/%Y"} to #{ending.strftime "%m/%d/%Y"}..."

    # the API serves a max of 1000 documents, no matter how it's paginated
    # fetch a page of 1000 documents
    # - this should be enough to not miss anything if filtered by month and type,
    #   but if not, catch it
    # - addendum: NOTICE type articles are more voluminous, and must be filtered per day, or week
    #   2/13/2013 - 3/13/2013, for example: over 2,800 notices. (Wow.)

    if options[:cache_lists]
      destination = list_cache :article, type, beginning, ending
    else
      destination = nil
    end

    unless response = Utils.download(base_url, options.merge(destination: destination, json: true))
      warnings << {msg: "Error while polling FR.gov (#{base_url}), aborting for now", url: base_url}
      return []
    end

    if response['errors']
      Report.exception self, "Errors, not sure what this looks like...", errors: response['errors']
      return []
    end

    unless response['count']
      Report.exception self, "No count field?", response: response.to_s
      return []
    end

    if response['count'] >= 1000
      Report.warning self, "Likely more than 1000 #{type} articles between #{ending} and #{beginning}"
      # continue on
    end

    count = 0

    # not an error, just means there's no results in this timeframe (like for future months)
    unless response['results']
      puts "No results for this time frame" if options[:debug]
      return []
    end

    response['results'].map do |article|
      article['document_number']
    end
  end


  def self.text_for(document_type, document_number, format, url, options)
    destination = destination_for document_type, document_number, format

    unless Utils.download(url, options.merge(destination: destination))
      # caller will file warning
      return nil
    end

    body = File.read destination

    if format == :html
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
    "https://www.federalregister.gov/api/v1/#{endpoint}/#{document_number}.json"
  end

  def self.destination_for(document_type, document_number, format)
    yearish = document_number.split("-").first
    "data/federalregister/#{yearish}/#{document_number}/#{document_type}.#{format}"
  end

  def self.list_cache(article_type, document_type, beginning, ending)
    begin_day = beginning.strftime "%Y-%m-%d"
    end_day = ending.strftime "%Y-%m-%d"
    "data/federalregister/lists/#{article_type}/#{document_type}/#{begin_day}-#{end_day}.json"
  end

  def self.citation_cache(document_number)
    yearish = document_number.split("-").first
    "data/citations/regulations/#{yearish}/#{document_number}/citations.json"
  end

  def self.html_cache(document_number)
    "data/unitedstates/documents/federal_register/article/#{document_number}.htm"
  end

  # bucket is set as unitedstates/documents, put into "federal_register/article"
  def self.html_remote(document_number)
    "federal_register/article/#{document_number}.htm"
  end

  def self.noon_utc_for(timestamp)
    time = Time.zone.parse timestamp
    time.getutc + (12-time.getutc.hour).hours
  end

end