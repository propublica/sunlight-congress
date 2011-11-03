require 'nokogiri'
require 'open-uri'

class DocumentsGaoReports

  def self.run(options = {})
    count = 0
    doc = Nokogiri::XML(open("http://www.gao.gov/rss/reports.xml"))

    doc.xpath('//item').each do |item|
      title = item.xpath('title').inner_text
      gao_id =  title.split(',')[0]
      plain_title = title.split(", ")[1...-2].join(", ")

      pdf_id = gao_id.gsub(/^GAO/, '').tr('-','').downcase
      pdf_url = "http://www.gao.gov/new.items/d#{pdf_id}.pdf"

      document = Document.find_or_initialize_by :gao_id => gao_id
        
      document.attributes = {
        :document_type => 'gao_report',
        :title => plain_title,
        :url => item.xpath('link').inner_text,
        :pdf_url => pdf_url,
        :posted_at => Time.parse(item.xpath('pubDate').inner_text.gsub('00:00:00','13:00:00'))
      }

      document.save!
      count += 1
    end

    Report.success self, "Created or updated #{count} GAO Reports"
  end

end