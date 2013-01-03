require 'csv'

class LegislatorsBulk

  # generate a backwards compatible version of legislators.csv,
  # that can replace the manually curated one in sunlightlabs/apidata 
  # and be loaded into the old Sunlight Labs Congress API

  def self.run(options = {})
    FileUtils.mkdir_p "data/sunlight"
    
    count = 0

    # start with all current members
    bioguide_ids = Legislator.where(in_office: true).map &:bioguide_id

    # include all people who used to be in the old data
    old_legislators = {}
    CSV.foreach("data/sunlight/old-legislators.csv") do |row|
      bioguide_ids << row[16]
      old_legislators[row[16]] = row
    end
    bioguide_ids = bioguide_ids.uniq


    eligible = Legislator.where(bioguide_id: {"$in" => bioguide_ids}).all

    if options[:limit]
      eligible = eligible[0...options[:limit].to_i]
    end

    CSV.open("data/sunlight/legislators.csv", "w") do |csv|
      csv << %w{
        title firstname middlename lastname name_suffix nickname 
        party state district in_office gender 
        phone fax website webform congress_office 
        bioguide_id votesmart_id fec_id govtrack_id crp_id twitter_id
        congresspedia_url youtube_url facebook_id 
        official_rss senate_class birthdate
      }

      eligible.each do |legislator|
        puts "[#{legislator.bioguide_id}] Processing..." if options[:debug]

        row = [
          legislator['title'],
          legislator['first_name'],
          legislator['middle_name'],
          legislator['last_name'],
          legislator['name_suffix'],
          legislator['nickname'],
          legislator['party'],
          legislator['state'],
          legislator['district'],
          (legislator['in_office'] ? "1" : "0"),
          legislator['gender'],
          legislator['phone'],
          legislator['fax'],
          legislator['website'],
          legislator['contact_form'],
          legislator['office'],

          legislator['bioguide_id'],
          legislator['votesmart_id'],
          (legislator['fec_ids'] || []).first,
          legislator['govtrack_id'],
          legislator['crp_id'],
          legislator['twitter_id'],
  
          # congresspedia url from old spreadsheet          
          old_legislators[legislator.bioguide_id] ? old_legislators[legislator.bioguide_id][22] : nil,
          
          youtube_for(legislator),
          legislator['facebook_id'],
          
          nil, # rss is gone

          legislator['senate_class'],
          legislator['birthday']
        ]

        csv << row

        count += 1
      end
    end

    Report.success self, "Saved legislators.csv with #{count} current legislators"
  end

  def self.youtube_for(legislator)
    if legislator['youtube_id']
      "http://youtube.com/#{legislator['youtube_id']}"
    else
      nil
    end
  end

end