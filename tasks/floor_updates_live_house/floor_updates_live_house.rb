require 'open-uri'
require 'nokogiri'

class FloorUpdatesLiveHouse
  
  def self.run(options = {})
    url = get_xml_url options
    return unless url # a warning report will have been filed
    
    count = 0
    failures = []
    
    xml = nil
    begin
      xml = open url
      xml = xml.read
    rescue Timeout::Error, Errno::ECONNRESET, Errno::ETIMEDOUT, Errno::ENETUNREACH
      Report.warning self, "Network error on fetching the floor log, can't go on."
      return
    end
    
    unless xml =~ /^<\?xml/
      Report.warning self, "No XML for that day, can't go on."
      return
    end
    
    doc = Nokogiri::XML xml
    
    
    session = session_for doc
    chamber = 'house'
    legislative_day = legislative_day_for doc
    legislative_day_stamp = legislative_day.strftime "%Y-%m-%d"
    year = legislative_day.year
    
    (doc/:floor_action).each do |action|
      timestamp = Time.parse action.at("action_time")['for-search']
      item = action.at("action_description").inner_text.strip
      
      unless update = FloorUpdate.where(:timestamp => timestamp, :chamber => chamber).first
        update = FloorUpdate.new(:timestamp => timestamp, :chamber => chamber, :events => item)
      end
      
      update.attributes = {
        :session => session,
        :legislative_day => legislative_day_stamp,
        :bill_ids => bill_ids_for(item, session),
        :roll_ids => roll_ids_for(item, year),
        :legislator_ids => legislator_ids_for(item)
      }
      
      if update.save
        count += 1
      else
        failures << floor_update.attributes
        puts "Failed to save floor update, will file report"
      end
      
    end
    
    if failures.any?
      Report.failure self, "Had #{failures.size} failures, attributes attached", :failures => failures
    end
    
    Report.success self, "Updated/created #{count} floor updates in the House."
  end
  
  def self.get_xml_url(options)
    if options[:day]
      date = Time.parse(options[:day]).strftime("%Y%m%d")
      "http://clerk.house.gov/floorsummary/Download.aspx?file=#{date}.xml"
    else
      
      html = nil
      begin
        html = open "http://clerk.house.gov/floorsummary/floor.aspx"
      rescue Timeout::Error, Errno::ECONNRESET, Errno::ETIMEDOUT, Errno::ENETUNREACH
        Report.warning self, "Network error on fetching the floor log, can't go on."
        return nil
      end
      
      doc = Nokogiri::HTML html
      
      elem = doc.css("a.downloadLink").first
      unless elem
        Report.warning self, "Couldn't find download link, can't go on"
        return nil
      end
      
      url = elem['href']
      
      # in case they switch to absolute links
      if url =~ /^http\:\/\//
        url
      else
        "http://clerk.house.gov/floorsummary/#{url}"
      end
    end
  end
  
  def self.session_for(doc)
    doc.at("legislative_congress")['congress'].to_i
  end
  
  def self.legislative_day_for(doc)
    Time.parse doc.at("legislative_day").text
  end
  
  def self.roll_ids_for(text, year)
    matches = text.scan(/Roll (?:no.|Call) (\d+)/i).map {|r| r.first}.uniq.compact
    matches.map {|number| "h#{number}-#{year}"}
  end
  
  def self.bill_ids_for(text, session)
    matches = text.scan(/((S\.|H\.)(\s?J\.|\s?R\.|\s?Con\.| ?)(\s?Res\.?)*\s?\d+)/i).map {|r| r.first}.uniq.compact
    matches.map {|code| "#{code.gsub(/con/i, "c").tr(" ", "").tr('.', '').downcase}-#{session}" }
  end
  
  def self.legislator_ids_for(text)
    []
  end
  
#   def extract_rolls(data, chamber, year):
#     roll_ids = []
#     
#     roll_re = re.compile('Roll (?:no.|Call) (\d+)', flags=re.IGNORECASE)
#     roll_matches = roll_re.findall(data)
#     
#     if roll_matches:
#       for number in roll_matches:
#           roll_id = "%s%s-%s" % (chamber[0], number, year)
#           if roll_id not in roll_ids:
#               roll_ids.append(roll_id)
#     
#     return roll_ids
#     
# 
# def extract_legislators(text, chamber, db):
#     legislator_names = []
#     bioguide_ids = []
#     
#     possibles = []
#     
#     if chamber == "house":
#         name_re = re.compile('((M(rs|s|r)\.){1}\s((\s?[A-Z]{1}[A-Za-z-]+){0,2})(,\s?([A-Z]{1}[A-Za-z-]+))?((\sof\s([A-Z]{2}))|(\s?\(([A-Z]{2})\)))?)')
#       
#         name_matches = re.findall(name_re, text)
#         if name_matches:
#             for n in name_matches:
#                 raw_name = n[0]
#                 query = {"chamber": "house"}
#                 
#                 if n[1]:
#                     if n[1] == "Mr." : query["gender"] = 'M'
#                     else: query['gender'] = 'F'
#                 if n[3]:
#                     query["last_name"] = n[3]
#                 if n[6]:
#                     query["first_name"] = n[6]
#                 if n[9]:
#                     query["state"] = n[9]
#                 elif n[11]:
#                     query["state"] = n[11]
#                     
#                 possibles = db['legislators'].find(query)
#             
#             if possibles.count() > 0:
#                 if text not in legislator_names:
#                     legislator_names.append(raw_name)
#                     
#             for p in possibles:
#                 if p['bioguide_id'] not in bioguide_ids:
#                     bioguide_ids.append(p['bioguide_id'])
#     
#     return (legislator_names, bioguide_ids)
  
end