require 'sunlight'

class Committees

  # options:
  #   cache: don't redownload the YAML files
  
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
    current_committees = YAML.load open("data/unitedstates/congress-legislators/committees-current.yaml")
    memberships = YAML.load open("data/unitedstates/congress-legislators/committee-membership-current.yaml")
    
    legislator_cache = {}

    bad_committees = []
    count = 0
    sub_count = 0
    
    # store committees and subcommittees as peers, *and* nest subcommittees inside their committee
    current_committees.each do |us_committee|
      committee_id = us_committee['thomas_id']
      committee = Committee.find_or_initialize_by committee_id: committee_id
      
      committee.attributes = attributes_for us_committee
      committee.attributes = memberships_for committee_id, nil, memberships, legislator_cache

      # us_committee['subcommittees'].each do |subcommittee|
      # end
      
      committee.save!
      count += 1
    end
    
    if bad_committees.any?
      Report.warning self, "Failed to save #{bad_committees.size} committee, attached", bad_committee: bad_committees
    end
    
    Report.success self, "Processed #{count} current committees"
  end
  
  def self.attributes_for(us_committee, parent_id = nil)
    attributes = {
      name: us_committee['name'],
      chamber: us_committee['type'],
      subcommittee: !parent_id.nil?
    }

    # optional fields
    ['address', 'senate_committee_id', 'house_committee_id', 'url', 'phone'].each do |field|
      if us_committee.has_key?(field)
        attributes[field.to_sym] = us_committee[field]
      end
    end

    if (us_committee['type'] == 'house') and us_committee['address']
      attributes[:office] = us_committee['address'].split("; ").first
    end
    
    attributes
  end

  def self.memberships_for(committee_id, subcommittee_id, memberships, legislator_cache)
    full_id = [committee_id, subcommittee_id].join ""

    unless memberships[full_id]
      puts "MISSING MEMBERSHIPS for #{full_id}"
      return {}
    end

    members = memberships[full_id].map do |member|
      legislator_cache[member['bioguide']] ||= Utils.legislator_for(Legislator.where(bioguide_id: member['bioguide']).first)
      {
        side: member['party'],
        rank: member['rank'],
        title: member['title'],
        legislator: legislator_cache[member['bioguide']]
      }
    end

    membership_ids = memberships[full_id].map {|m| m['bioguide']}

    {
      members: members,
      membership_ids: membership_ids
    }
  end

end