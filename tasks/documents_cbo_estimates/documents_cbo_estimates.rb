require 'nokogiri'
require 'open-uri'

class DocumentsCboEstimates

  # CBO_URL = 'http://www.cbo.gov/costestimates/CEBrowse.cfm'
  CBO_URL = 'http://cbo.gov/cost-estimates/rss.xml'

  def self.run(options = {})

    unless xml = content_for(CBO_URL)
      Report.warning self, "Network error fetching CBO Estimates, can't go on.", :url => CBO_URL
      return
    end

    doc = Nokogiri::XML xml
    num_added = 0


    (doc/:item).each do |item|
      url = item.search("link").inner_text
      estimate_id = url.match(/(\d+)$/)[1]
      title = item.search("title").inner_text.strip
      description = item.search("description").inner_text.strip
      posted_at = Time.parse item.search("pubDate").inner_text
      categories = item.search("category").map {|c| c.inner_text.strip}
      
      # treat description as own html document, strip of tags and 'read more' link
      desc_doc = Nokogiri::HTML description
      description = desc_doc.inner_text.gsub(/read more$/, '').strip

      document = Document.find_or_initialize_by :estimate_id => estimate_id
      document.attributes = {
        :document_type => 'cbo_estimate',
        :estimate_id => estimate_id,
        :title => title,
        :url => url,
        :posted_at => posted_at,
        :description => description,
        :categories => categories
      }

      document.save!
      num_added += 1

      puts "[#{estimate_id}] Created new CBO estimate" if options[:debug]
    end

    Report.success self, "Added #{num_added} CBO Cost Estimates"
  end

  def self.content_for(url)
    begin
      open(url).read
    rescue Timeout::Error, Errno::ECONNRESET, Errno::ETIMEDOUT, Errno::ENETUNREACH
      nil
    end
  end

end
