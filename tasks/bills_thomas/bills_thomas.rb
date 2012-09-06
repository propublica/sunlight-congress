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

    unless File.exists?("data/thomas/bills/#{session}")
      Report.failure self, "Data not available on disk for the requested session of Congress."
      return
    end
    
    unless options[:skip_sync]
      puts "Syncing committees from GovTrack..." if options[:debug]
      FileUtils.mkdir_p "data/govtrack"
      unless system("rsync -az govtrack.us::govtrackdata/us/committees.xml data/govtrack/committees.xml")
        Report.failure self, "Couldn't rsync to Govtrack.us for committees.xml."
        return
      end
    end
    
    # legislator cache
    legislators = {}
    
    cached_committees = cached_committees_for session, Nokogiri::XML(open("data/govtrack/committees.xml"))
    
    if options[:bill_id]
      bill_ids = [options[:bill_id]]
    else
      paths = Dir.glob("data/thomas/bills/#{session}/*/*")
      bill_ids = paths.map {|path| "#{File.basename(path).sub "con", "c"}-#{session}"}
      if options[:limit]
        bill_ids = bills.first options[:limit].to_i
      end
    end
    
    
    bill_ids.each do |bill_id|
      type, number, session, code, chamber = Utils.bill_fields_from bill_id
      
      thomas_type = Utils.gpo_type_for type # thomas parser uses same bill types
      path = "data/thomas/bills/#{session}/#{thomas_type}/#{thomas_type}#{number}/data.json"

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
      
      # committees = committees_for filename, doc, cached_committees, missing_committees
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
        summary: doc['summary'],
        state: doc['state'],
        sponsor: sponsor,
        sponsor_id: (sponsor ? sponsor['bioguide_id'] : nil),
        cosponsors: cosponsors,
        cosponsor_ids: cosponsors.map {|c| c['bioguide_id']},
        cosponsors_count: cosponsors.size,
        actions: actions,
        last_action: last_action,
        last_action_at: last_action ? last_action[:acted_at] : nil,
        :passage_votes => passage_votes,
        :passage_votes_count => passage_votes.size,
        :last_passage_vote_at => last_passage_vote_at,
        introduced_at: Utils.ensure_utc(doc['introduced_at']),
        keywords: doc['subjects'],
        # :committees => committees,
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
    elsif legislator = legislator_match(sponsor['name'], sponsor['title'], sponsor['state'], sponsor['district'])
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
      elsif person = legislator_match(cosponsor['name'], cosponsor['title'], cosponsor['state'], cosponsor['district'])
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
  
  
  def self.committees_for(filename, doc, cached_committees, missing_committees)
    committees = {}
    
    doc.search("//committees/committee").each do |elem|
      activity = elem['activity'].split(/, ?/).map {|a| a.downcase}
      committee_name = elem['name']
      subcommittee_name = elem['subcommittee']
      
      if subcommittee_name.blank? # we're not getting subcommittees, way too hard to match them up
        if committee = committee_match(committee_name, cached_committees)
          committees[committee['committee_id']] = {
            :activity => activity,
            :committee => Utils.committee_for(committee)
          }
        else
          missing_committees << [committee_name, filename]
        end
      end
    end
    
    committees
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

  # this is terrible, and temporary
  def self.legislator_match(name, title, state, district)
    last_name, rest = name.split(/,\s?/)
    first_name, middle_name = rest.split(" ")

    # hardcoded - a couple weird last names, mostly people who moved chambers
    if last_name == "McMorris Rodgers"
      bioguide_id = "M001159"
    elsif last_name == "Herrera Beutler"
      bioguide_id = "H001056"
    elsif last_name == "Diaz-Balart" and first_name == "Mario"
      bioguide_id = "D000600"
    elsif last_name == "Diaz-Balart" and first_name == "Lincoln" 
      bioguide_id = "D000299"
    elsif last_name == "Boozman"
      bioguide_id = "B001236"
    elsif last_name == "Blunt"
      bioguide_id = "B000575"
    elsif last_name == "Moran" and state == "KS"
      bioguide_id = "M000934"
    elsif last_name == "Moran" and state == "VA"
      bioguide_id = "M000933"
    elsif last_name == "Heller"
      bioguide_id = "H001041"
    elsif last_name == "Jackson-Lee"
      bioguide_id = "J000032"
    elsif last_name == "Hunter" and middle_name == "D."
      bioguide_id = "H001048"
    end

    if bioguide_id
      return Utils.legislator_for(Legislator.where(bioguide_id: bioguide_id).first)
    end

    if title == "Sen"
      criteria = {last_name: last_name, chamber: "senate", state: state}
    else
      criteria = {last_name: last_name, chamber: "house", state: state, district: (district || "0")}
    end
    
    match = nil

    number = Legislator.where(criteria).count
    if number > 1
      criteria[:first_name] = first_name

      number = Legislator.where(criteria).count
      if number == 1
        match = Legislator.where(criteria).first
      else
        criteria.delete :first_name
        criteria[:nickname] = first_name
        number = Legislator.where(criteria).count
        if number == 1
          match = Legislator.where(criteria).first
        else
          criteria[:middle_name] = middle_name
          number = Legislator.where(criteria).count
          if number == 1
            match = Legislator.where(criteria).first
          else
            puts "Too many results even after narrowing for #{criteria.inspect}"
          end
        end
      end
    elsif number == 0
      puts "No results for #{criteria.inspect}, giving up"
    elsif number == 1
      match =  Legislator.where(criteria).first
    end

    match ? Utils.legislator_for(match) : nil
  end
  
  def self.committee_match(name, cached_committees)
    Committee.where(:committee_id => cached_committees[name]).first
  end
  
  def self.cached_committees_for(session, doc)
    committees = {}
    
    doc.search("/committees/committee/thomas-names/name[@session=#{session}]").each do |elem|
      committees[elem.text] = Utils.committee_id_for elem.parent.parent['code']
    end
    
    # hardcode in a fix to a usual problem, sigh
    committees["House Ethics"] = "HSSO"
    committees["Senate Caucus on International Narcotics Control"] = "SCNC"
    committees["Commission on Security and Cooperation in Europe (Helsinki Commission)"] = "JCSE"
    
    committees
  end

end