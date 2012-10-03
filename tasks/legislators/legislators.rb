require 'sunlight'

class Legislators

  def self.run(options = {})
    sync_united_states!(options) and sync_sunlight!(options)
  end

  def self.sync_united_states!(options = {})
    
    # wipe and re-clone the unitedstates legislators repo
    FileUtils.mkdir_p "data/unitedstates"
    FileUtils.rm_rf "data/unitedstates/congress-legislators"
    unless system "git clone git://github.com/unitedstates/congress-legislators.git data/unitedstates/congress-legislators"
      Report.error self, "Couldn't clone legislator data from unitedstates."
      return false
    end
    puts

    puts "Loading in YAML files..." if options[:debug]
    current_legislators = YAML.load open("data/unitedstates/congress-legislators/legislators-current.yaml")
    historical_legislators = YAML.load open("data/unitedstates/congress-legislators/legislators-historical.yaml")

    bad_legislators = []
    count = 0

    # store every single legislator
    (current_legislators + historical_legislators).each do |us_legislator|
      bioguide_id = us_legislator['id']['bioguide']
      puts "[#{bioguide_id}] Processing legislator from unitedstates..." if options[:debug]

      legislator = Legislator.find_or_initialize_by bioguide_id: bioguide_id

      legislator.attributes = attributes_from_united_states us_legislator

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

  def self.sync_sunlight!(options = {})
    Sunlight::Base.api_key = options[:config]['sunlight_api_key']
    
    bad_legislators = []
    count = 0
    
    puts "Contacting Sunlight API..." if options[:debug]
    api_legislators = Sunlight::Legislator.all_where :all_legislators => 1
    
    api_legislators.each do |api_legislator|
      bioguide_id = api_legislator.bioguide_id
      puts "[#{bioguide_id}] Processing legislator from API..." if options[:debug]

      unless legislator = Legislator.where(bioguide_id: bioguide_id).first
        bad_legislators << {bioguide_id: bioguide_id, message: "Couldn't locate legislator in Sunlight API by bioguide"}
        next
      end
      
      legislator.attributes = attributes_from_api api_legislator
      
      if legislator.save
        count += 1
      else
        bad_legislators << {attributes: legislator.attributes, errors: legislator.errors.full_messages}
      end
    end
    
    if bad_legislators.any?
      Report.warning self, "Failed to save #{bad_legislators.size} API legislators, attached", bad_legislators: bad_legislators
    end
    
    Report.success self, "Processed #{count} legislators from API"
  end
  

  def self.attributes_from_united_states(us_legislator)
    {
      ids: us_legislator['id'],
      names: us_legislator['name'],
      other_names: us_legislator['other_names'],
      bio: us_legislator['bio'],
      terms: us_legislator['terms']
    }
  end
    
  def self.attributes_from_api(api_legislator)
    {
      in_office: api_legislator.in_office,
      govtrack_id: api_legislator.govtrack_id,
      votesmart_id: api_legislator.votesmart_id,
      crp_id: api_legislator.crp_id,
      first_name: api_legislator.firstname,
      nickname: api_legislator.nickname,
      last_name: api_legislator.lastname,
      middle_name: api_legislator.middlename,
      name_suffix: api_legislator.name_suffix,
      state: api_legislator.state,
      :district => api_legislator.district,
      :party => api_legislator.party,
      :title => api_legislator.title,
      :gender => api_legislator.gender,
      :phone => api_legislator.phone,
      :website => api_legislator.website,
      :congress_office => api_legislator.congress_office,
      :twitter_id => api_legislator.twitter_id,
      :youtube_url => api_legislator.youtube_url,
      
      :chamber => {
          'Rep' => 'house',
          'Sen' => 'senate',
          'Del' => 'house',
          'Com' => 'house'
        }[api_legislator.title]
    }
  end
  
end