class BillsThomas
  
  # options:
  #   session: The session of Congress to update.
  #   bill_id: The particular bill to update. Useful for development.
  #   limit: A limit on the number of processed bills. Useful for development.
  #   skip_sync: Don't sync to GovTrack for committee information.

  def self.run(options = {})
    session = options[:session] ? options[:session].to_i : Utils.current_session
    
    count = 0
    missing_legislators = []
    missing_committees = []
    bad_bills = []

    unless File.exists?("data/unitedstates/congress/#{session}/bills")
      Report.failure self, "Data not available on disk for the requested session of Congress."
      return
    end
    
    # caches
    legislators = {}
    committee_cache = {}
    
    if options[:bill_id]
      bill_ids = [options[:bill_id]]
    else
      paths = Dir.glob("data/unitedstates/congress/#{session}/bills/*/*")
      bill_ids = paths.map {|path| "#{File.basename(path).sub "con", "c"}-#{session}"}
      if options[:limit]
        bill_ids = bill_ids.first options[:limit].to_i
      end
    end
    
    
    bill_ids.each do |bill_id|
      type, number, session, code, chamber = Utils.bill_fields_from bill_id
      
      thomas_type = Utils.gpo_type_for type # thomas parser uses same bill types
      path = "data/unitedstates/congress/#{session}/bills/#{thomas_type}/#{thomas_type}#{number}/data.json"

      doc = Oj.load open(path)
      
      bill = Bill.find_or_initialize_by bill_id: bill_id
      
      if doc['sponsor']
        sponsor = sponsor_for doc['sponsor'], legislators
        missing_legislators << [bill_id, doc['sponsor']] if sponsor.nil?
      else
        sponsor = nil # occurs at least in hjres45-111, debt ceiling bill
      end

      cosponsors, missing = cosponsors_for doc['cosponsors'], legislators
      missing_legislators << missing.map {|m| [bill_id, missing]} if missing.any?

      actions = actions_for(doc['actions'])
      last_action = last_action_for actions
      
      committees, missing = committees_for doc['committees'], session, committee_cache
      missing_committees << missing.map {|m| [bill_id, missing]} if missing.any?

      related_bills = related_bills_for doc['related_bills']
      
      passage_votes = passage_votes_for actions
      last_passage_vote_at = passage_votes.last ? passage_votes.last[:voted_at] : nil
      
      bill.attributes = {
        bill_type: type,
        number: number,
        code: code,
        session: session,
        chamber: {'h' => 'house', 's' => 'senate'}[type.first.downcase],
        short_title: doc['short_title'],
        official_title: doc['official_title'],
        popular_title: doc['popular_title'],
        titles: doc['titles'],
        summary: summary_for(doc['summary']),
        state: doc['status'],
        enacted_as: doc['enacted_as'],
        sponsor: sponsor,
        sponsor_id: (sponsor ? sponsor['bioguide_id'] : nil),
        cosponsors: cosponsors,
        cosponsor_ids: cosponsors.map {|c| c['bioguide_id']},
        cosponsors_count: cosponsors.size,
        actions: actions,
        last_action: last_action,
        last_action_at: last_action ? last_action['acted_at'] : nil,
        passage_votes: passage_votes,
        passage_votes_count: passage_votes.size,
        last_passage_vote_at: last_passage_vote_at,
        introduced_at: Utils.ensure_utc(doc['introduced_at']),
        keywords: doc['subjects'],
        committees: committees,
        related_bills: related_bills,
        abbreviated: false
      }
      
      # merge in timeline attributes
      bill.attributes = history_for doc['history']
      
      if bill.save
        count += 1
        puts "[#{bill_id}] Saved successfully" if options[:debug]
      else
        bad_bills << {attributes: bill.attributes, error_messages: bill.errors.full_messages}
        puts "[#{bill_id}] Error saving, will file report"
      end
    end

    if missing_legislators.any?
      missing_legislators = missing_legislators.uniq
      Report.warning self, "Found #{missing_legislators.size} unmatchable legislators, attached.", {missing_legislators: missing_legislators}
    end
    
    if missing_committees.any?
      missing_committees = missing_committees.uniq
      Report.warning self, "Found #{missing_committees.size} missing committee IDs or subcommittee names, attached.", {missing_committees: missing_committees}
    end
    
    if bad_bills.any?
      Report.failure self, "Failed to save #{bad_bills.size} bills. Attached the last failed bill's attributes and errors.", bill: bad_bills.last
    end
    
    Report.success self, "Synced #{count} bills for session ##{session} from GovTrack.us."
  end
  
  # just process the dates, sigh
  def self.actions_for(actions)
    actions.map do |action|
      action['acted_at'] = Utils.ensure_utc action['acted_at']
      action
    end
  end

  def self.history_for(history)
    times = %w{ enacted_at vetoed_at house_passage_result_at senate_passage_result_at 
      house_override_result_at senate_override_result_at awaiting_signature_since }
    times.each do |field|
      history[field] = Utils.ensure_utc(history[field]) if history[field]
    end

    history
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
  
  def self.cosponsors_for(cosponsors, legislators)
    new_cosponsors = []
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
        new_cosponsors << person.merge(
          sponsored_at: Utils.ensure_utc(cosponsor['sponsored_at']),
          withdrawn_at: (Utils.ensure_utc(cosponsor['withdrawn_at']) if cosponsor['withdrawn_at'])
        )
      else
        missing << cosponsor
      end

    end

    [new_cosponsors, missing]
  end
  
  # go through the actions and find the last one that is in the past
  # (some bills will have future scheduled committee hearings as "actions")
  def self.last_action_for(actions)
    return nil if actions.size == 0
    
    now = Time.now
    actions.reverse.each do |action|
      return action if action['acted_at'] < now
    end
    
    nil
  end
  
  def self.passage_votes_for(actions)
    chamber = {'h' => 'house', 's' => 'senate'}
    actions.select {|a| (a['type'] == 'vote') or (a['type'] == 'vote2')}.map do |action|
      voted_at = Utils.ensure_utc action['acted_at']
      chamber_code = action['where']
      how = action['how']
      
      result = {
        how: how,
        result: action['result'], 
        voted_at: voted_at,
        text: action['text'],
        chamber: chamber[chamber_code],
        passage_type: action['type']
      }
      
      if action['roll'].present?
        result[:roll_id] = "#{chamber_code}#{action['roll']}-#{voted_at.year}"
      end
      
      result
    end
  end
  
  
  def self.committees_for(elements, session, committee_cache)
    committees = {}
    missing = []
    
    elements.each do |committee|
      # we're not getting subcommittees, way too hard to match them up
      next if committee['subcommittee'].present?

      if match = committee_match(committee['committee_id'], session, committee_cache)
        committees[match['committee_id']] = {
          activity: committee['activity'],
          committee: match
        }
      else
        missing << committee['committee']
      end
    end
    
    [committees, missing]
  end

  def self.related_bills_for(related_bills)
    related = {}
    
    related_bills.each do |details|
      relation = details['reason']
      bill_id = details['bill_id']
      
      related[relation] ||= []
      related[relation] << bill_id
    end
    
    related
  end

  def self.legislator_for(thomas_id)
    legislator = Legislator.where(thomas_id: thomas_id).first
    legislator ? Utils.legislator_for(legislator) : nil
  end
  
  def self.committee_match(id, session, committee_cache)
    unless committee_cache[id]
      if committee = Committee.where(committee_id: id).first
        committee_cache[id] = Utils.committee_for(committee)
      end
    end

    committee_cache[id]
  end

  def self.summary_for(summary)
    summary.is_a?(Hash) ? summary['text'] : summary
  end

end