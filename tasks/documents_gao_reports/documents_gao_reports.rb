# encoding: utf-8

require 'nokogiri'
require 'docsplit'

class DocumentsGaoReports

  # Fetches and indexes GAO reports. Can fetch entire years; by default, asks for the last 7 days.
  # options:
  #   gao_id: specify a single report by its GAO ID.
  #   year: fetch a whole year's reports.
  #   limit: a number, limit the number of reports found.
  #   cache: fetch everything from the disk, no network requests.

  def self.run(options = {})

    if options[:gao_id]
      gao_ids = [options[:gao_id]]
    else
      if options[:year]
        beginning = Time.parse("#{options[:year]}-01-01").midnight
        ending = Time.parse("#{options[:year]}-12-31").midnight
      else
        ending = Time.now.midnight
        beginning = ending - 7.days
      end

      gao_ids = gao_ids_for beginning, ending, options

      if options[:limit]
        gao_ids = gao_ids.first options[:limit].to_i
      end
    end

    count = 0
    failures = []
    warnings = []

    puts "Going to fetch #{gao_ids.size} GAO reports..." if options[:debug]

    gao_ids.each do |gao_id|
      url = "http://gao.gov/products/#{gao_id}"

      cache = cache_path_for gao_id, "landing.html"
      unless body = Utils.download(url, options.merge(destination: cache))
        failures << {gao_id: gao_id, url: url, message: "Couldn't download landing page"}
        next
      end
      
      doc = Nokogiri::HTML body


      # find source links

      pdf_url = nil
      text_url = nil

      if pdf_elem = doc.css("a.pdf_link").select {|l| l.text.strip =~ /^View Report/i}.first
        pdf_url = URI.join("http://www.gao.gov", pdf_elem['href']).to_s
      else
        if gao_id =~ /SP$/
          puts "[#{gao_id}] No PDF link, report likely a supplement, skipping" if options[:debug]
          next
        end
        
        puts "[#{gao_id}] Couldn't find PDF link, skipping as failure"
        failures << {gao_id: gao_id, url: url, body: body, message: "Couldn't find PDF link"}
        next
      end

      if text_elem = doc.css("a.link").select {|l| l.text.strip =~ /Accessible Text/i}.first
        text_url = URI.join("http://www.gao.gov", text_elem['href']).to_s
      end


      # find title, category, and publication date

      unless title = doc.css("div#summary_head h2").text.strip
        puts "[#{gao_id}] Couldn't find title, failed"
        failures << {gao_id: gao_id, url: url, message: "Couldn't find title"}
        next
      end      

      posted_at = nil
      timestamp = doc.css("div#summary_head span.grey_text").text
      unless timestamp.present? and (posted_at = Time.parse(timestamp).strftime("%Y-%m-%d"))
        puts "[#{gao_id}] Couldn't find publish date, failed"
        failures << {gao_id: gao_id, url: url, timestamp: timestamp, message: "Couldn't find publish date"}
        next
      end

      category = doc.css("div#summary_head h1").text.strip
      category = nil if category == "" # don't
      

      # figure out whether we can get the full text
      full_text = nil

      # always download the PDF, just to have it
      if pdf_url
        cache = cache_path_for gao_id, "pdf"
        unless Utils.download(pdf_url, options.merge(destination: cache))
          warnings << {gao_id: gao_id, url: pdf_url, message: "Couldn't download PDF of report"}
        end
      end

      # if GAO provides an "Accessible Text" version, use that
      if text_url
        cache = cache_path_for gao_id, "txt"
        unless full_text = Utils.download(text_url, options.merge(destination: cache))
          warnings << {gao_id: gao_id, url: text_url, message: "Couldn't download text version of report"}
        end

      # otherwise, create a file in the same place using a rip of the PDF
      elsif pdf_url
        pdf_path = cache_path_for gao_id, "pdf"
        output = cache_path_for gao_id, "txt"

        if File.exists?(pdf_path)
          # depending on Docsplit's behavior of just changing the extension
          Docsplit.extract_text(pdf_path, ocr: false, output: File.dirname(output))

          full_text = File.read(output) if File.exists?(output)
        end
      end


      attributes = {
        title: title,
        posted_at: posted_at,
        document_type: 'gao_report',
        url: "#{url}?source=sunlight", # maybe someday GAO will notice us

        gao_id: gao_id,
        source_urls: {pdf: pdf_url, text: text_url},
        categories: [category] # use plural field because other docs use it
      }

      # save to Mongo
      puts "[#{gao_id}] Saving report information..." if options[:debug]
      document = Document.find_or_initialize_by gao_id: gao_id
      document.attributes = attributes
      document.save!

      # save to ElasticSearch if we got the text
      if full_text
        # post-process, strip newlines
        full_text = process_full_text full_text

        puts "[#{gao_id}] Indexing full text..." if options[:debug]
        document_id = "gao-#{gao_id}"
        attributes['text'] = full_text
        begin
          Utils.es_store! 'documents', document_id, attributes
        rescue Exception => ex
          warnings << {gao_id: gao_id, message: "Error indexing text, moving on"}.merge(Report.exception_to_hash(ex))
        end
      end

      puts "[#{gao_id}] Successfully saved report"

      count += 1
    end

    Utils.es_refresh!

    if failures.any?
      Report.failure self, "Failed to process #{failures.size} reports, attached", {failures: failures}
    end

    if warnings.any?
      Report.warning self, "Failed to process text for #{warnings.size} reports, attached", {warnings: warnings}
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

    Nokogiri::HTML(body).css("div.listing a").map do |link|
      link['href'].split("/").last.strip
    end
  end

  def self.cache_path_for(gao_id, extension)
    "data/gao/#{gao_id}/#{gao_id}.#{extension}"
  end

  # collapse whitespace
  def self.process_full_text(full_text)
    full_text = full_text.encode("ASCII-8BIT", :invalid => :replace, :undef => :replace)
    full_text.gsub /[\s\n]+/, " "
  end
end