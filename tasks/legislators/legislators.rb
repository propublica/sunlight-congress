class Legislators

  # options:
  #   cache: don't re-download unitedstates data
  #   current: limit to current legislators only
  #   limit: stop after N legislators
  #   clear: wipe the db of legislators first

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

    us_legislators = current_legislators.map {|l| [l, true]} 
    unless options[:current]
      historical_legislators = YAML.load open("data/unitedstates/congress-legislators/legislators-historical.yaml")
      us_legislators += historical_legislators.map {|l| [l, false]}
    end

    # wipe db if requested
    Legislator.delete_all if options[:clear]

    # limit if requested
    us_legislators = us_legislators.to_a
    us_legislators = us_legislators.first(options[:limit].to_i) if options[:limit]

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
      Report.warning self, "Failed to save #{bad_legislators.size} united_states legislators.", bad_legislators: bad_legislators
    end
    
    Report.success self, "Processed #{count} legislators from unitedstates"
  end

  
  def self.attributes_from_united_states(us_legislator, current)
    last_term = us_legislator['terms'].last

    attributes = {
      in_office: current,

      thomas_id: us_legislator['id']['thomas'].to_i.to_s,
      govtrack_id: us_legislator['id']['govtrack'].to_s,
      votesmart_id: us_legislator['id']['votesmart'].to_s,
      crp_id: us_legislator['id']['opensecrets'].to_s,
      fec_ids: us_legislator['id']['fec'],

      first_name: us_legislator['name']['first'],
      nickname: us_legislator['name']['nickname'],
      last_name: us_legislator['name']['last'],
      middle_name: us_legislator['name']['middle'],
      name_suffix: us_legislator['name']['suffix'],
      gender: us_legislator['bio'] ? us_legislator['bio']['gender'] : nil,
      birthday: us_legislator['bio'] ? us_legislator['bio']['birthday'] : nil,

      term_start: last_term['start'],
      term_end: last_term['end'],
      state: last_term['state'],
      state_name: state_map[last_term['state']],
      district: last_term['district'],
      party: party_for(last_term['party']),
      title: last_term['type'].capitalize,
      chamber: {
        'rep' => 'house',
        'sen' => 'senate',
        'del' => 'house',
        'com' => 'house'
      }[last_term['type']],

      phone: last_term['phone'],
      fax: last_term['fax'],
      website: last_term['url'],
      office: last_term['office'],
      contact_form: last_term['contact_form'],

      terms: terms_for(us_legislator)
    }

    if us_legislator['other_names']
      attributes[:other_names] = us_legislator['other_names']
    end

    if attributes[:chamber] == "senate"
      attributes[:senate_class] = last_term['class']
      attributes[:lis_id] = us_legislator['id']['lis'].to_s
    end

    attributes
  end

  def self.party_for(us_party)
    {
      'Democrat' => 'D',
      'Republican' => 'R',
      'Independent' => 'I'
    }[us_party] || us_party
  end
    
  def self.social_media_from(details)
    facebook = details['social']['facebook_graph']
    facebook = facebook.to_s if facebook
    {
      twitter_id: details['social']['twitter'],
      youtube_id: details['social']['youtube'],
      facebook_id: facebook
    }
  end

  def self.terms_for(us_legislator)
    us_legislator['terms'].map do |term|
      # these go on the top level and are only correct for the current term
      ['phone', 'fax', 'url', 'address', 'office', 'contact_form'].each {|field| term.delete field}

      type = term.delete 'type'

      term['party'] = party_for term['party']
      term['title'] = type.capitalize
      term['chamber'] = {
        'rep' => 'house',
        'sen' => 'senate',
        'del' => 'house',
        'com' => 'house'
      }[type]

      term
    end
  end

  def self.state_map
    @state_map ||= {
      "AL" => "Alabama",
      "AK" => "Alaska",
      "AZ" => "Arizona",
      "AR" => "Arkansas",
      "CA" => "California",
      "CO" => "Colorado",
      "CT" => "Connecticut",
      "DE" => "Delaware",
      "DC" => "District of Columbia",
      "FL" => "Florida",
      "GA" => "Georgia",
      "HI" => "Hawaii",
      "ID" => "Idaho",
      "IL" => "Illinois",
      "IN" => "Indiana",
      "IA" => "Iowa",
      "KS" => "Kansas",
      "KY" => "Kentucky",
      "LA" => "Louisiana",
      "ME" => "Maine",
      "MD" => "Maryland",
      "MA" => "Massachusetts",
      "MI" => "Michigan",
      "MN" => "Minnesota",
      "MS" => "Mississippi",
      "MO" => "Missouri",
      "MT" => "Montana",
      "NE" => "Nebraska",
      "NV" => "Nevada",
      "NH" => "New Hampshire",
      "NJ" => "New Jersey",
      "NM" => "New Mexico",
      "NY" => "New York",
      "NC" => "North Carolina",
      "ND" => "North Dakota",
      "OH" => "Ohio",
      "OK" => "Oklahoma",
      "OR" => "Oregon",
      "PA" => "Pennsylvania",
      "PR" => "Puerto Rico",
      "RI" => "Rhode Island",
      "SC" => "South Carolina",
      "SD" => "South Dakota",
      "TN" => "Tennessee",
      "TX" => "Texas",
      "UT" => "Utah",
      "VT" => "Vermont",
      "VA" => "Virginia",
      "WA" => "Washington",
      "WV" => "West Virginia",
      "WI" => "Wisconsin",
      "WY" => "Wyoming"
    }
  end
  
end