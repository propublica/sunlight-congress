class Bills
  
  # options:
  #   congress: The congress to update.
  #   bill_id: The particular bill to update. Useful for development.
  #   limit: A limit on the number of processed bills. Useful for development.
  #   skip_sync: Don't sync to GovTrack for committee information.

  def self.run(options = {})
    congress = options[:congress] ? options[:congress].to_i : Utils.current_congress
    
    count = 0
    missing_legislators = []
    missing_committees = []
    bad_bills = []

    unless File.exists?("data/unitedstates/congress/#{congress}/bills")
      Report.failure self, "Data not available on disk for the requested Congress."
      return
    end
    
    legislators = {}
    committee_cache = {}
    
    if options[:bill_id]
      bill_ids = [options[:bill_id]]
    else
      paths = Dir.glob("data/unitedstates/congress/#{congress}/bills/*/*")
      bill_ids = paths.map {|path| "#{File.basename path}-#{congress}"}
      if options[:limit]
        bill_ids = bill_ids.first options[:limit].to_i
      end
    end
    
    
    bill_ids.each do |bill_id|
      type, number, congress, chamber = Utils.bill_fields_from bill_id
      
      path = "data/unitedstates/congress/#{congress}/bills/#{type}/#{type}#{number}/data.json"

      doc = Oj.load open(path)
      
      bill = Bill.find_or_initialize_by bill_id: bill_id
      
      if doc['sponsor']
        sponsor = sponsor_for doc['sponsor'], legislators
        missing_legislators << [bill_id, doc['sponsor']] if sponsor.nil?
      else
        sponsor = nil # occurs at least in hjres45-111, debt ceiling bill
      end

      cosponsors, withdrawn, missing = cosponsors_for doc['cosponsors'], legislators
      missing_legislators += missing.map {|m| [bill_id, m]} if missing.any?

      actions = actions_for doc['actions']

      summary = summary_for doc['summary']
      summary_short = short_summary_for summary
      summary_date = summary_date_for doc['summary']
      
      committees, missing = committees_for doc['committees'], committee_cache
      missing_committees += missing.map {|m| [bill_id, m]} if missing.any?

      # todo: when amendments are supported, 
      # pass on a full related_bills field with the original fields.
      related_bill_ids = doc['related_bills'].map {|details| details['bill_id']}.compact
      
      votes = votes_for actions
      
      bill.attributes = {
        bill_type: type,
        number: number,
        congress: congress,
        chamber: {'h' => 'house', 's' => 'senate'}[type.first.downcase],
        
        short_title: doc['short_title'],
        official_title: doc['official_title'],
        popular_title: doc['popular_title'],

        keywords: doc['subjects'],
        summary: summary,
        summary_short: summary_short,
        summary_date: summary_date,
        
        sponsor: sponsor,
        sponsor_id: (sponsor ? sponsor['bioguide_id'] : nil),
        cosponsors: cosponsors,
        cosponsor_ids: cosponsors.map {|c| c['legislator']['bioguide_id']},
        cosponsors_count: cosponsors.size,
        withdrawn_cosponsors: withdrawn,
        withdrawn_cosponsor_ids: withdrawn.map {|c| c['legislator']['bioguide_id']},
        withdrawn_cosponsors_count: withdrawn.size,

        introduced_on: doc['introduced_at'],
        history: history_for(doc['history']),
        enacted_as: enacted_as_for(doc),

        actions: actions,
        last_action: actions ? actions.last : nil,
        last_action_at: actions.any? ? actions.last['acted_at'] : nil,

        votes: votes,
        last_vote_at: votes.last ? votes.last['acted_at'] : nil,

        committees: committees,
        committee_ids: committees.map {|c| c['committee']['committee_id']},
        related_bill_ids: related_bill_ids,

        urls: urls_for(bill_id)
      }

      if bill.save
        # work-around - last_action_at and last_vote_at can both be dates or times,
        # and Mongo does not order these correctly together when times are turned into 
        # Mongo native time objects. So, we serialize them to a string before saving it.
        ['last_action_at', 'last_vote_at'].each do |field|
          if bill[field]
            bill[field] = bill[field].xmlschema unless bill[field].is_a?(String)
            bill.set(field, bill[field])
          end
        end
        
        count += 1
        puts "[#{bill_id}] Saved successfully" if options[:debug]
      else
        bad_bills << {attributes: bill.attributes, error_messages: bill.errors.full_messages}
        puts "[#{bill_id}] Error saving, will file report"
      end
    end

    if missing_legislators.any?
      missing_legislators = missing_legislators.uniq
      Report.warning self, "Found #{missing_legislators.size} unmatchable legislators.", {missing_legislators: missing_legislators}
    end
    
    if missing_committees.any?
      missing_committees = missing_committees.uniq
      Report.warning self, "Found #{missing_committees.size} missing committee IDs or subcommittee names.", {missing_committees: missing_committees}
    end
    
    if bad_bills.any?
      Report.failure self, "Failed to save #{bad_bills.size} bills.", bill: bad_bills.last
    end
    
    Report.success self, "Synced #{count} bills for congress ##{congress} from THOMAS.gov."
  end

  def self.sponsor_for(sponsor, legislators)
    # cached by thomas ID
    if legislators[sponsor['thomas_id']]
      legislators[sponsor['thomas_id']] 
    elsif legislator = legislator_for(sponsor['thomas_id'])
      # cache it for next time
      legislators[sponsor['thomas_id']] = legislator
      legislator
    else
      # no match, this needs to get reported
      nil
    end
  end

  # just make sure all the dates are in UTC
  def self.history_for(history)
    new_history = history.dup
    history.each do |key, value|
      if (key =~ /_at$/) and (value[":"])
        new_history[key] = Utils.utc_parse(value)
      end
    end
    new_history
  end
  
  def self.cosponsors_for(cosponsors, legislators)
    new_cosponsors = []
    withdrawn_cosponsors = []
    missing = []

    cosponsors.each do |cosponsor|
      person = nil

      if legislators[cosponsor['thomas_id']]
        person = legislators[cosponsor['thomas_id']]
      elsif person = legislator_for(cosponsor['thomas_id'])
        # cache it for next time
        legislators[cosponsor['thomas_id']] = person
      end

      if person
        cosponsorship = {'sponsored_on' => cosponsor['sponsored_at']}
        if cosponsor['withdrawn_on']
          cosponsorship['withdrawn_on'] = cosponsor['withdrawn_at']
          withdrawn_cosponsors << cosponsorship.merge('legislator' => person)
        else
          new_cosponsors << cosponsorship.merge('legislator' => person)
        end
      else
        missing << cosponsor
      end

    end

    [new_cosponsors, withdrawn_cosponsors, missing]
  end
  
  # clean up on some fields in actions
  def self.actions_for(actions)
    now = Time.now

    actions.map do |action|
      if action['acted_at'].is_a?(String)
        time = Time.parse(action['acted_at'])
      else
        time = action['acted_at']
      end

      # discard future 'actions', that's not what this is about
      next if time > now

      if action['acted_at'] =~ /:/
        action['acted_at'] = Utils.utc_parse action['acted_at']
      end

      if where = action.delete('where')
        action['chamber'] = {'h' => 'house', 's' => 'senate'}[where]

        # can only do this if 'where' is present (which it should be)
        if roll = action.delete('roll')
          action['roll_id'] = "#{where}#{roll}-#{time.year}"
        end
      end

      # not ready to commit to having these yet
      action.delete 'committee'
      action.delete 'subcommittee'
      action.delete 'in_committee'
      action.delete 'status'

      action
    end.compact
  end
  
  def self.votes_for(actions)
    actions.select do |action| 
      (action['type'] =~ /vote/)
    end
  end
    
  def self.committees_for(elements, committee_cache)
    committees = []
    missing = []
    
    elements.each do |committee|
      # we're not getting subcommittees, way too hard to match them up
      if committee['subcommittee_id'].present?
        committee_id = committee['committee_id'] + committee['subcommittee_id']
      else
        committee_id = committee['committee_id']
      end

      if match = committee_match(committee_id, committee_cache)
        committees << {
          'activity' => committee['activity'],
          'committee' => match
        }
      else
        missing << committee_id
      end
    end
    
    [committees, missing]
  end

  def self.legislator_for(thomas_id)
    legislator = Legislator.where(thomas_id: thomas_id).first
    legislator ? Utils.legislator_for(legislator) : nil
  end
  
  def self.committee_match(id, committee_cache)
    unless committee_cache[id]
      if committee = Committee.where(committee_id: id).first
        committee_cache[id] = Utils.committee_for(committee)
      end
    end

    committee_cache[id]
  end

  def self.summary_for(summary)
    summary ? summary['text'] : nil
  end

  def self.summary_date_for(summary)
    summary ? summary['date'] : nil
  end

  def self.short_summary_for(summary)
    return nil unless summary

    max = 1000
    if summary.size <= max
      summary
    else
      summary[0..max] + "..."
    end
  end

  def self.urls_for(bill_id)
    type, number, congress, chamber = Utils.bill_fields_from bill_id
    {
      congress: congress_gov_url(congress, type, number),
      govtrack: govtrack_url(congress, type, number),
      opencongress: opencongress_url(congress, type, number)
    }
  end

  def self.opencongress_url(congress, type, number)
    id = "#{congress}-#{govtrack_type type}#{number}"
    "http://www.opencongress.org/bill/#{id}/show"
  end
  
  def self.govtrack_url(congress, type, number)
    "http://www.govtrack.us/congress/bills/#{congress}/#{type}#{number}"
  end
  
  # todo: when they expand to earlier (or later) congresses, 'th' is not a universal ordinal
  def self.congress_gov_url(congress, type, number)
    "http://beta.congress.gov/bill/#{congress}th/#{congress_gov_type type}/#{number}"
  end

  def self.govtrack_type(bill_type)
    {
      "hr" => "h",
      "hres" => "hr",
      "hjres" => "hj",
      "hconres" => "hc",
      "s" => "s",
      "sres" => "sr",
      "sjres" => "sj",
      "sconres" => "sc"
    }[bill_type]
  end
  
  def self.congress_gov_type(bill_type)
    {
      "hr" => "house-bill",
      "hres" => "house-resolution",
      "hconres" => "house-concurrent-resolution",
      "hjres" => "house-joint-resolution",
      "s" => "senate-bill",
      "sres" => "senate-resolution",
      "sconres" => "senate-concurrent-resolution",
      "sjres" => "senate-joint-resolution"
    }[bill_type]
  end

  def self.enacted_as_for(doc)
    return nil unless doc['enacted_as']
    
    enacted_as = doc['enacted_as'].dup
    enacted_as['congress'] = enacted_as['congress'].to_i
    enacted_as['number'] = enacted_as['number'].to_i
    enacted_as
  end
end