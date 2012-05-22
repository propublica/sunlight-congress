require 'open-uri'
require 'httparty'

class DocumentsCrsReports

  def self.run(options = {})

    key = options[:config]['opencrs_api_key']
    test_url = "https://opencrs.com/api/reports/list.json?key=#{key}&page=1"

   unless html = content_for(test_url)
     Report.warning self, "Network error fetching CRS Reports, can't go on.", :url => test_url
     return
   end

    num_added = 0
    (1..5).each do |page|
      response = HTTParty.get "https://opencrs.com/api/reports/list.json?key=#{key}&page=#{page}"
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

  def self.content_for(url)
    begin
      open(url).read
    rescue Timeout::Error, Errno::ECONNRESET, Errno::ETIMEDOUT, Errno::ENETUNREACH
      nil
    end
  end


end
