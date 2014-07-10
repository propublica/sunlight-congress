require 'csv'

class LegislatorsBulk

  # generate a backwards compatible version of legislators.csv,
  # that can replace the manually curated one in sunlightlabs/apidata
  # and be loaded into the old Sunlight Labs Congress API

  def self.run(options = {})
    FileUtils.mkdir_p "data/sunlight"

    old_csv = "misc/old-legislators.csv"
    new_csv = "data/sunlight/legislators.csv"

    count = 0

    # start with all current members
    bioguide_ids = Legislator.where(in_office: true).map &:bioguide_id

    # include all people who used to be in the old data
    old_legislators = {}
    CSV.foreach(old_csv) do |row|
      bioguide_ids << row[16]
      old_legislators[row[16]] = row
    end
    bioguide_ids = bioguide_ids.uniq


    eligible = Legislator.where(bioguide_id: {"$in" => bioguide_ids}).all

    if options[:limit]
      eligible = eligible[0...options[:limit].to_i]
    end

    eligible = eligible.sort_by {|l| l['bioguide_id']}

    CSV.open(new_csv, "w") do |csv|
      csv << %w{
        title firstname middlename lastname name_suffix nickname
        party state district in_office gender
        phone fax website oc_email webform congress_office
        bioguide_id votesmart_id fec_id govtrack_id crp_id twitter_id
        congresspedia_url youtube_url facebook_id
        official_rss senate_class birthdate
      }

      eligible.each do |legislator|
        puts "[#{legislator.bioguide_id}] Processing..." if options[:debug]

        old_legislator = old_legislators[legislator.bioguide_id]

        row = [
          legislator['title'],
          legislator['first_name'],
          legislator['middle_name'],
          legislator['last_name'],
          legislator['name_suffix'],
          legislator['nickname'],

          legislator['party'],
          legislator['state'],

          # for senators, copies old designations, adds Jr to new ones
          district_for(legislator, old_legislator),

          (legislator['in_office'] ? "1" : "0"),
          legislator['gender'],
          legislator['phone'],
          legislator['fax'],
          legislator['website'],
          legislator['oc_email'],
          legislator['contact_form'],
          legislator['office'],

          legislator['bioguide_id'],
          legislator['votesmart_id'],
          (legislator['fec_ids'] || []).first,
          legislator['govtrack_id'],
          legislator['crp_id'],
          legislator['twitter_id'],

          # congresspedia url from old spreadsheet
          old_legislators[legislator.bioguide_id] ? old_legislator[22] : nil,

          youtube_for(legislator),
          legislator['facebook_id'],

          nil, # rss is gone

          (legislator['senate_class'] ? ("I" * legislator['senate_class']) : nil),
          legislator['birthday']
        ]

        csv << row

        count += 1
      end
    end

    # now to upload to S3
    if options[:backup]
      Utils.backup! :legislators, new_csv, "legislators.csv"
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

  def self.district_for(legislator, old_legislator)
    if legislator['chamber'] == 'senate'
      if legislator['state_rank'].nil? and old_legislator and (old_legislator[0] == "Sen") and old_legislator[8]
        old_legislator[8]
      else
        "#{legislator['state_rank'].capitalize} Seat"
      end
    else
      legislator['district']
    end
  end

end