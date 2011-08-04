require 'httparty'

class DocumentsCrsReports

  def self.run(options = {})
    num_added = 0
    key = options[:config][:opencrs_api_key]

    (1..5).each do |page|
      response = HTTParty.get "http://opencrs.com/api/reports/list.json?key=#{key}&page=#{page}"
      response.each do |r|
        if Document.first(:conditions => { :order_code => r['ordercode'] })
          break
        else
          num_added += 1
          puts r['dateadded'].to_s
          Document.create(:document_type => 'crs_report',
                          :posted_at => Time.parse(r['dateadded'].to_s + " 12:00 UTC"),
                          :order_code => r['ordercode'],
                          :title => r['title'],
                          :url => r['download_url'],
                          :released_at => Time.parse(r['releasedate'].to_s + " 12:00 UTC"),
                          :opencrs_url => r['opencrs_url'])
        end
      end
    end

    Report.success self, "Added #{num_added} CRS Reports"
  end

end
