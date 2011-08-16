require 'nokogiri'
require 'open-uri'

class DocumentsCboEstimates

  def self.run(options = {})
    num_added = 0
    doc = Nokogiri::HTML(open("http://www.cbo.gov/costestimates/CEBrowse.cfm"))

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

end
