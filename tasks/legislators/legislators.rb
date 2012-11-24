require 'sunlight'

class Legislators

  # options:
  #   cache: don't re-download unitedstates data
  #   current: limit to current legislators only

  def self.run(options = {})
    
    # wipe and re-clone the unitedstates legislators repo
    unless options[:cache]
      FileUtils.mkdir_p "data/unitedstates"
      FileUtils.rm_rf "data/unitedstates/congress-legislators"
      unless system "git clone git://github.com/unitedstates/congress-legislators.git data/unitedstates/congress-legislators"
        Report.error self, "Couldn't clone legislator data from unitedstates."
        return false
      end
      puts
    end

    puts "Loading in YAML files..." if options[:debug]
    current_legislators = YAML.load open("data/unitedstates/congress-legislators/legislators-current.yaml")
    
    social_media = YAML.load open("data/unitedstates/congress-legislators/legislators-social-media.yaml")
    social_media_cache = {}
    social_media.each {|details| social_media_cache[details['id']['bioguide']] = details}

    bad_legislators = []
    count = 0

    us_legislators = current_legislators.map {|l| [l,true]} 
    unless options[:current]
      historical_legislators = YAML.load open("data/unitedstates/congress-legislators/legislators-historical.yaml")
      us_legislators += historical_legislators.map {|l| [l, false]}
    end

    # store every single legislator
    us_legislators.each do |us_legislator, current|
      bioguide_id = us_legislator['id']['bioguide']
      puts "[#{bioguide_id}] Processing #{current ? "active" : "inactive"} legislator from unitedstates..." if options[:debug]

      legislator = Legislator.find_or_initialize_by bioguide_id: bioguide_id
      legislator.attributes = attributes_from_united_states us_legislator, current

      # append social media if present
      if social_media_cache[bioguide_id]
        legislator.attributes = social_media_from social_media_cache[bioguide_id]
      end

      if legislator.save
        count += 1
      else
        bad_legislators << {attributes: legislator.attributes, errors: legislator.errors.full_messages}
      end
    end

    if bad_legislators.any?
      Report.warning self, "Failed to save #{bad_legislators.size} united_states legislators, attached", bad_legislators: bad_legislators
    end
    
    Report.success self, "Processed #{count} legislators from unitedstates"
  end

  
  def self.attributes_from_united_states(us_legislator, current)
    last_term = us_legislator['terms'].last

    {
      in_office: current,

      thomas_id: us_legislator['id']['thomas'].to_i.to_s,
      govtrack_id: us_legislator['id']['govtrack'].to_s,
      votesmart_id: us_legislator['id']['votesmart'].to_s,
      lis_id: us_legislator['id']['lis'].to_s,
      crp_id: us_legislator['id']['opensecrets'],
      first_name: us_legislator['name']['first'],
      nickname: us_legislator['name']['nickname'],
      last_name: us_legislator['name']['last'],
      middle_name: us_legislator['name']['middle'],
      name_suffix: us_legislator['name']['suffix'],
      gender: us_legislator['bio'] ? us_legislator['bio']['gender'] : nil,

      other_names: us_legislator['other_names'],

      state: last_term['state'],
      district: last_term['district'],
      party: party_for(last_term['party']),
      title: last_term['type'].capitalize,
      phone: last_term['phone'],
      website: last_term['url'],
      congress_office: last_term['office'],
      chamber: {
        'rep' => 'house',
        'sen' => 'senate',
        'del' => 'house',
        'com' => 'house'
      }[last_term['type']]
    }
  end

  def self.party_for(us_party)
    {
      'Democrat' => 'D',
      'Republican' => 'R',
      'Independent' => 'I'
    }[us_party] || us_party
  end

  def self.youtube_url_for(username)
    "http://www.youtube.com/#{username}"
  end
    
  def self.social_media_from(details)
    {
      twitter_id: details['social']['twitter'],
      youtube_url: youtube_url_for(details['social']['youtube'])
    }
  end
  
end