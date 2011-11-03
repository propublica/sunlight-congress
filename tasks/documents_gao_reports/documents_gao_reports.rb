require 'nokogiri'
require 'open-uri'

class DocumentsGaoReports

  def self.run(options = {})
    num_added = 0
    doc = Nokogiri::XML(open("http://www.gao.gov/rss/reports.xml"))

    doc.xpath('//item').each do |item|
      gao_id =  item.xpath('title').inner_text.split(',')[0]
      
      if Document.first(:conditions => { :gao_id => gao_id })
        next
      else
        num_added += 1
        Document.create(:document_type => 'gao_report',
                        :gao_id => gao_id,
                        :title => item.xpath('title').inner_text,
                        :url => item.xpath('link').inner_text,
                        :posted_at => Time.parse(item.xpath('pubDate').inner_text.gsub('00:00:00','13:00:00')))
      end
    end

    Report.success self, "Added #{num_added} GAO Reports"
  end

end
