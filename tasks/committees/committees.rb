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

    count = 0
    sub_count = 0
    
    # we only store current committees
    Committee.delete_all

    # store committees and subcommittees as peers, *and* nest subcommittees inside their committee
    current_committees.each do |us_committee|
      committee_id = us_committee['thomas_id']
      committee = Committee.find_or_initialize_by committee_id: committee_id
      
      committee.attributes = attributes_for us_committee
      committee.attributes = memberships_for committee_id, memberships, legislator_cache

      subcommittees = []
      (us_committee['subcommittees'] || []).each do |us_subcommittee|
        subcommittee_id = us_subcommittee['thomas_id']
        full_id = [committee_id, subcommittee_id].join ""

        subcommittee = Committee.find_or_initialize_by committee_id: full_id

        # basic attributes
        attributes = attributes_for us_subcommittee, committee
        subcommittees << attributes
        subcommittee.attributes = attributes

        subcommittee[:parent_committee_id] = committee_id
        subcommittee.attributes = memberships_for full_id, memberships, legislator_cache

        subcommittee.save!
        sub_count += 1
      end

      committee.attributes = {subcommittees: subcommittees}
      
      committee.save!
      count += 1
    end
    
    Report.success self, "Processed #{count} committees and #{sub_count} subcommittees"
  end
  
  def self.attributes_for(us_committee, parent_committee = nil)
    attributes = {
      name: us_committee['name']
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

    if parent_committee
      attributes[:chamber] = parent_committee[:chamber]
      attributes[:subcommittee] = true
    else
      attributes[:chamber] = us_committee['type']
      attributes[:subcommittee] = false
    end
    
    attributes
  end

  def self.memberships_for(committee_id, memberships, legislator_cache)
    unless memberships[committee_id]
      puts "MISSING MEMBERSHIPS for #{committee_id}"
      return {}
    end

    members = memberships[committee_id].map do |member|
      legislator_cache[member['bioguide']] ||= Utils.legislator_for(Legislator.where(bioguide_id: member['bioguide']).first)
      {
        side: member['party'],
        rank: member['rank'],
        title: member['title'],
        legislator: legislator_cache[member['bioguide']]
      }
    end

    membership_ids = memberships[committee_id].map {|m| m['bioguide']}

    {
      members: members,
      member_ids: membership_ids
    }
  end

end