# encoding: utf-8

require 'nokogiri'
require 'open-uri'

class DocumentsGaoReports

  def self.run(options = {})
    # get the list of the latest reports
    url = 'http://www.gao.gov/rss/reports.xml'
    unless xml = Utils.download(url, options) # don't cache ever
      Report.warning self, "Network error fetching GAO Reports, can't go on.", url: url
      return
    end

    count = 0
    doc = Nokogiri::XML xml

    failures = []
    warnings = []

    doc.xpath('//item').each do |item|
      title = item.xpath('title').inner_text
      gao_id =  title.split(',')[0]
      plain_title = title.split(", ")[1...-2].join(", ")

      # post date
      posted_at = Time.parse(item.xpath('pubDate').inner_text.gsub('00:00:00','13:00:00'))

      # strip the source
      url = item.xpath('link').inner_text
      url = url.sub(/\?source=ra$/, "")

      
      # fetch the links to the PDF and full text
      cache = cache_path_for gao_id, posted_at.year, "landing.html"
      unless source_urls = source_urls_for(url, cache, options)
        failures << {gao_id: gao_id, url: url, message: "Couldn't find source URLs"}
        next
      end

      full_text = nil

      if source_urls
        cache = cache_path_for gao_id, posted_at.year, "#{gao_id}.txt"
        unless full_text = Utils.download(source_urls[:text], options.merge(destination: cache))
          warnings << {gao_id: gao_id, url: source_urls[:text], message: "Couldn't download text version of report"}
        end

        cache = cache_path_for gao_id, posted_at.year, "#{gao_id}.pdf"
        unless Utils.download(source_urls[:pdf], options.merge(destination: cache))
          warnings << {gao_id: gao_id, url: source_urls[:pdf], message: "Couldn't download PDF of report"}
        end
      end

      attributes = {
        document_type: 'gao_report',
        gao_id: gao_id,
        title: plain_title,
        url: "#{url}?source=sunlight", # maybe someday GAO will notice us
        source_urls: source_urls,
        posted_at: posted_at
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
        Utils.es_store! 'documents', document_id, attributes
      end

      count += 1
    end

    Utils.es_refresh! 'documents' # refresh ES index

    Report.success self, "Created or updated #{count} GAO Reports"
  end

  def self.source_urls_for(url, destination, options)
    body = Utils.download url, options.merge(destination: destination)
    return nil unless body
    
    pdf_url = nil
    text_url = nil
    doc = Nokogiri::HTML body

    if pdf_elem = doc.css("a.pdf_link").select {|l| l.text.strip =~ /^View Report/i}.first
      pdf_url = URI.join("http://www.gao.gov", pdf_elem['href']).to_s
    end

    if text_elem = doc.css("a.link").select {|l| l.text.strip =~ /Accessible Text/i}.first
      text_url = URI.join("http://www.gao.gov", text_elem['href']).to_s
    end

    if pdf_url and text_url
      {pdf: pdf_url, text: text_url}
    else
      nil
    end
  end

  def self.cache_path_for(gao_id, year, filename)
    "data/gpo/#{year}/#{gao_id}/#{filename}"
  end

  # collapse whitespace
  def self.process_full_text(full_text)
    full_text = full_text.encode("ASCII-8BIT", :invalid => :replace, :undef => :replace)
    full_text.gsub /[\s\n]+/, " "
  end
end