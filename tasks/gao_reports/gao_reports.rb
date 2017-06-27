require 'nokogiri'
require 'docsplit'

class GaoReports

  # Fetches and indexes GAO reports. Can fetch entire years; by default, asks for the last 7 days.
  # options:
  #   gao_id: specify a single report by its GAO ID.
  #   year: fetch a whole year's reports.
  #   limit: a number, limit the number of reports found.
  #   cache: fetch available docs from the disk.

  def self.run(options = {})

    if options[:gao_id]
      gao_ids = [options[:gao_id]]
    else
      if options[:year]
        beginning = Time.parse("#{options[:year]}-01-01").midnight
        ending = Time.parse("#{options[:year]}-12-31").midnight
      elsif options[:month]
        beginning = Time.parse("#{options[:month]}-01").midnight
        ending = Time.parse("#{options[:month]}-31").midnight
      else
        ending = Time.now.midnight
        beginning = ending - 30.days
      end

      gao_ids = gao_ids_for beginning, ending, options

      if options[:limit]
        gao_ids = gao_ids.first options[:limit].to_i
      end
    end

    if gao_ids.nil?
      Report.warning self, "GAO seems down, couldn't list recent reports."
      return
    end

    options[:batch_size] ||= 1000
    count = 0
    failures = []
    warnings = []

    batcher = [] # used to persist a batch indexing container

    puts "Going to fetch #{gao_ids.size} GAO reports..." if options[:debug]

    gao_ids.each do |gao_id|

      url = "http://www.gao.gov/api/id/#{gao_id}"
      cache = cache_path_for gao_id, "report.json"
      unless details = Utils.download(url, options.merge(destination: cache, json: true))
        failures << {gao_id: gao_id, url: url, message: "Couldn't download JSON of report"}
        next
      end

      details = details.first # it's an array of one item for some reason

      # details directly from JSON
      categories = details['topics'] || []
      categories += [details['bucket_term']] if details['bucket_term']
      published_on = details['docdate']
      posted_at = Time.parse details['actual_release_date']
      report_number = details['rptno']
      title = details['title']
      gao_type = details['document_type']
      description = strip_tags(details['description']) if details['description'].present?

      # urls
      landing_url = details['url']
      text_url = details['text_url']
      pdf_url = details['pdf_url']

      # seen a mixup - http://gao.gov/api/id/586393
      if pdf_url and (pdf_url =~ /\.txt$/)
        text_url = pdf_url
        pdf_url = nil
      # seen it - http://gao.gov/api/id/586175
      elsif pdf_url and (pdf_url !~ /\.pdf$/)
        pdf_url = nil
      end

      unless landing_url or pdf_url
        puts "[#{gao_id}] No landing URL or PDF, skipping..." if options[:debug]
        next
      end

      # figure out whether we can get the full text
      full_text = nil

      # always download the PDF, just to have it
      if pdf_url
        cache = cache_path_for gao_id, "report.pdf"
        unless Utils.download(pdf_url, options.merge(destination: cache))
          warnings << {gao_id: gao_id, url: pdf_url, message: "Couldn't download PDF of report"}
        end
      end

      # if GAO provides an "Accessible Text" version, use that
      if text_url and (text_url =~ /\.txt$/)
        cache = cache_path_for gao_id, "report.download.txt"
        unless full_text = Utils.download(text_url, options.merge(destination: cache))
          warnings << {gao_id: gao_id, url: text_url, message: "Couldn't download text version of report"}
        end

        # if the text is downloaded, needs to be treated as ISO-8859-1 and then converted to UTF-8
        full_text.force_encoding("ISO-8859-1")
        full_text = full_text.encode "UTF-8", :invalid => :replace, :undef => :replace

      # "Accessible PDF" that we seem to be able to scrape the text out of - cdunwell 4/19/2016
      elsif text_url and (text_url =~ /\.pdf$/)
        txt_path = cache_path_for gao_id, "report.txt.pdf"
        unless full_text = Utils.download(text_url, options.merge(destination: txt_path))
          warnings << {gao_id: gao_id, url: text_url, message: "Couldn't download accessible pdf version of report"}
        end

        output = cache_path_for gao_id, "report.txt"

        if File.exists?(txt_path)
          # depending on Docsplit's behavior of just changing the extension
          Docsplit.extract_text(txt_path, ocr: false, output: File.dirname(output))

          full_text = File.read(output) if File.exists?(output)
        end

      # "Accessible PDF" that we seem to be able to scrape the text out of - cdunwell 4/19/2016
      elsif text_url and (text_url =~ /\.pdf$/)
        txt_path = cache_path_for gao_id, "report.txt.pdf"
        unless full_text = Utils.download(text_url, options.merge(destination: txt_path))
          warnings << {gao_id: gao_id, url: text_url, message: "Couldn't download accessible pdf version of report"}
        end

        output = cache_path_for gao_id, "report.txt"

        if File.exists?(txt_path)
          # depending on Docsplit's behavior of just changing the extension
          Docsplit.extract_text(txt_path, ocr: false, output: File.dirname(output))

          full_text = File.read(output) if File.exists?(output)
        end

      # otherwise, create a file in the same place using a rip of the PDF
      elsif pdf_url
        pdf_path = cache_path_for gao_id, "report.pdf"
        output = cache_path_for gao_id, "report.txt"

        if File.exists?(pdf_path)
          # depending on Docsplit's behavior of just changing the extension
          Docsplit.extract_text(pdf_path, ocr: false, output: File.dirname(output))

          full_text = File.read(output) if File.exists?(output)
        end
      end

      document_id = "GAO-#{gao_id}"

      attributes = {
        document_id: document_id,
        document_type: 'gao_report',
        document_type_name: "GAO Report",

        posted_at: posted_at,
        published_on: published_on,

        title: title,
        categories: categories,

        url: (landing_url || pdf_url),
        source_url: pdf_url,

        gao_report: {
          gao_id: gao_id,
          report_number: report_number,
          supplement_url: details['supplement_url'],
          youtube_id: details['youtube_id'],
          links: (details['additional_links'] if details['additional_links'].present?),
          description: description
        }
      }

      # save to Mongo
      puts "[#{gao_id}] Saving report information..." if options[:debug]
      document = Document.find_or_initialize_by document_id: document_id
      document.attributes = attributes

      # save to ElasticSearch if we got the text
      if full_text
        full_text = process_full_text full_text

        unless citation_ids = Utils.citations_for(document, full_text, citation_cache(gao_id), options)
          warnings << {message: "Failed to extract citations from #{document_id}"}
          citation_ids = []
        end

        document['citation_ids'] = citation_ids # for Mongo
        attributes['citation_ids'] = citation_ids # for ES

        puts "[#{gao_id}] Indexing full text..." if options[:debug]
        attributes['text'] = full_text

        Utils.es_batch! 'documents', document_id, attributes, batcher, options
      end

      document.save!

      puts "[#{gao_id}] Successfully saved report"

      count += 1
    end

    Utils.es_flush! 'documents', batcher

    if failures.any?
      Report.failure self, "Failed to process #{failures.size} reports", {failures: failures}
    end

    if warnings.any?
      Report.warning self, "Failed to process text for #{warnings.size} reports", {warnings: warnings}
    end

    Report.success self, "Created or updated #{count} GAO Reports"
  end

  # fetch search results for date range, return GAO IDs for every report in the list
  def self.gao_ids_for(beginning, ending, options)
    url = "http://gao.gov/browse/date/custom"
    url << "?adv_begin_date=#{beginning.strftime("%m/%d/%Y")}"
    url << "&adv_end_date=#{ending.strftime("%m/%d/%Y")}"
    url << "&rows=15000" # 2011 had 835, 2010 had 794

    cache = "data/gao/#{beginning.strftime("%Y%m%d")}-#{ending.strftime("%Y%m%d")}.html"
    body = Utils.download(url, options.merge(destination: cache))
    return nil unless body

    Nokogiri::HTML(body).css("div.listing").map do |div|
      div['data-content_id']
    end
  end

  def self.cache_path_for(gao_id, filename)
    "data/gao/#{gao_id}/#{filename}"
  end

  def self.citation_cache(gao_id)
    "data/citations/gao_reports/#{gao_id}/citations.json"
  end

  # I should use sanitize or loofah for this
  def self.strip_tags(text)
    text = text.gsub(/<\/?(p|div)>/i, "\n\n").strip
    text.gsub! /<[^>]+?>/, '' # don't yell at me
    text.gsub! /\n{3,}\s*/, "\n\n"
    text.strip
  end

  # collapse whitespace
  def self.process_full_text(full_text)

    full_text.gsub! '``', '"'
    full_text.gsub! "''", '"'
    full_text.gsub! /[\s\n]+/, " "

    full_text
  end
end
