require 'sunlight'

class Committees

  # options:
  #   cache: don't redownload the YAML files
  #   session: session of Congress, for purpose of caring about
  #     whether we have membership data or not
  
  def self.run(options = {})
    session = options[:session] ? options[:session].to_i : Utils.current_session

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
    
    # committees who do not spell out what congress they are in
    bad_committees = []
    # *current* committees for which we lack members
    missing_members = []

    legislator_cache = {}

    count = 0
    sub_count = 0

    
    # we only store current committees
    Committee.delete_all

    # store committees and subcommittees as peers, *and* nest subcommittees inside their committee
    current_committees.each do |us_committee|
      committee_id = us_committee['thomas_id']
      
      # we need to know whether it's current or historical
      unless us_committee['congresses']
        bad_committees << committee_id
        next
      end

      committee = Committee.find_or_initialize_by committee_id: committee_id
      
      committee.attributes = attributes_for us_committee

      if committee[:congresses].include?(session)
        committee.attributes = memberships_for committee, memberships, legislator_cache, missing_members
      end

      subcommittees = []
      (us_committee['subcommittees'] || []).each do |us_subcommittee|
        subcommittee_id = us_subcommittee['thomas_id']
        full_id = [committee_id, subcommittee_id].join ""

        # we need to know whether it's current or historical
        unless us_subcommittee['congresses']
          puts "No 'congresses' field for #{full_id}" if options[:debug]
          bad_committees << full_id
          next
        end

        subcommittee = Committee.find_or_initialize_by committee_id: full_id

        # basic attributes
        attributes = attributes_for us_subcommittee, committee
        subcommittees << attributes
        subcommittee.attributes = attributes

        if committee[:congresses].include?(session)
          subcommittee.attributes = memberships_for committee, memberships, legislator_cache, missing_members
        end

        subcommittee[:parent_committee_id] = committee_id
        subcommittee.save!
        sub_count += 1
      end

      committee.attributes = {subcommittees: subcommittees}
      
      committee.save!
      count += 1
    end

    if bad_committees.any?
      Report.warning self, "Unable to process #{bad_committees.size} committees", bad_committees: bad_committees
    end

    if missing_members.any?
      Report.warning self, "Missing members for #{missing_members.size} current committees", missing_members: missing_members
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

    if us_committee['congresses']
      attributes[:congresses] = us_committee['congresses'].split(/, ?/).map &:to_i
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

  # could be either a committee or subcommittee, this function should be blind
  def self.memberships_for(committee, memberships, legislator_cache, missing_members)
    committee_id = committee.committee_id

    unless memberships[committee_id]
      puts "MISSING MEMBERSHIP for #{committee_id}"
      missing_members << committee_id
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