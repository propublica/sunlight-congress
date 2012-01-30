require 'nokogiri'
require 'open-uri'

class DocumentsCboEstimates

  CBO_URL = 'http://www.cbo.gov/costestimates/CEBrowse.cfm'

  def self.run(options = {})

    unless html = content_for(CBO_URL)
      Report.warning self, "Network error fetching CBO Estimates, can't go on.", :url => CBO_URL
      return
    end

    doc = Nokogiri::HTML(html)
    num_added = 0

    doc.css("div.listdocs p").each do |p|
      title_node = p.css('a.doctitle')
      href = title_node.attribute('href').to_s
      estimate_id = href.split('=')[1]

      if Document.first(:conditions => { :estimate_id => estimate_id })
        break
      else
        num_added += 1
        Document.create(:document_type => 'cbo_estimate',
                        :estimate_id => estimate_id,
                        :title => title_node.inner_text,
                        :url => 'http://www.cbo.gov' + href,
                        :posted_at => Time.parse(p.css('span.docdate').inner_text + " 12:00 UTC"),
                        :description => p.inner_text.split('pdf')[1])
      end
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
