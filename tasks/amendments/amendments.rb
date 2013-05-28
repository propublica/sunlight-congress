# reads in amendments from the unitedstates/congress project
# mixes in to the Bill stream, with a document_type of 'amendment'
# options:
  #   congress: limit to a particular congress' worth of amendment's.
  #   amendment_id: limit to a particular amendment.
  #   limit: Limit to a number of amendments total.

require "./tasks/bills/bills"

class Amendments

  def self.run(options)
    congress = options[:congress]
    count = 0

    missing_bills = []
    missing_amendments = []
    missing_committees = []
    missing_people = []
    bad_amendments = []

    legislators = {}
    Legislator.where(thomas_id: {"$exists" => true}).only(Legislator.basic_fields).each do |legislator|
      legislators[legislator.thomas_id] = Utils.legislator_for legislator
    end

    amendment_ids = []
    if options[:amendment_id]
      amendment_ids = [options[:amendment_id]]
    else
      paths = Dir.glob("data/unitedstates/congress/#{congress}/amendments/*/*")
      amendment_ids = paths.map {|path| "#{File.basename path}-#{congress}"}

      if options[:limit]
        amendment_ids = amendment_ids.first options[:limit].to_i
      end
    end

    # sorting by chamber/number is necessary, ensures amendments which
    # amend prior amendments can find them
    amendment_ids.sort! do |a, b|
      as = Utils.amendment_fields_from a
      bs = Utils.amendment_fields_from b

      if as[3] == bs[3] # chamber
        as[1] <=> bs[1] # number
      else
        as[3] <=> bs[3]
      end

    end

    amendment_ids.each do |amendment_id|
      amendment = Amendment.find_or_initialize_by amendment_id: amendment_id

      type, number, congress, chamber = Utils.amendment_fields_from amendment_id

      path = "data/unitedstates/congress/#{congress}/amendments/#{type}/#{type}#{number}/data.json"
      doc = Oj.load open(path)

      introduced_on = Utils.utc_parse doc['introduced_at']
      proposed_on = Utils.utc_parse(doc['proposed_at']) if doc['proposed_at']

      actions = Bills.actions_for doc['actions']

      # if there's no actions, set the last action as the proposed or introduced date
      if actions.last
        last_action_at = actions.last['acted_at']
      else
        last_action_at = proposed_on || introduced_on
      end

      # purpose and description stats for 111th Congress up until 2013-05-21:
      # 11,608 amendments -
      #   1,839 with description and purpose
      #   29 with description and no purpose
      #   2,856 with purpose and no description
      #   6,884 with no purpose and no description

      amendment.attributes = {
        congress: congress,
        number: number,
        chamber: chamber,

        introduced_on: introduced_on,
        proposed_on: proposed_on,

        purpose: doc['purpose'],
        description: doc['description'],

        actions: actions,
        last_action: actions.last,
        last_action_at: last_action_at
      }

      if chamber == "house"
        amendment[:house_number] = doc['house_number']
        amendment[:offered_order] = doc['offered_order']
      end


      # amendments can be sponsored by people or committees, sigh
      sponsor_type = doc['sponsor']['type']

      if sponsor_type == 'person'
        if sponsor = Bills.sponsor_for(doc['sponsor'], legislators)
          sponsor_id = sponsor['bioguide_id']
        else
          sponsor_id = nil
          missing_people << [amendment_id, doc['sponsor']]
        end
      else
        if sponsor = sponsor_committee_for(doc['sponsor'])
          sponsor_id = sponsor['committee_id']
        else
          sponsor_id = nil
          missing_committees << [amendment_id, doc['sponsor']]
        end
      end

      amendment.attributes = {
        sponsor_type: sponsor_type,
        sponsor: sponsor,
        sponsor_id: sponsor_id
      }

      if doc['amends_bill']
        amendment['amends_bill_id'] = doc['amends_bill']['bill_id']
        if amended_bill = Utils.bill_for(doc['amends_bill']['bill_id'])
          amendment['amends_bill'] = amended_bill
        else
          missing_bills << {amendment_id: amendment_id, bill_id: doc['amends_bill']['bill_id']}
        end
      end

      if doc['amends_treaty']
        amendment['amends_treaty_id'] = doc['amends_treaty']['treaty_id']
      end

      if doc['amends_amendment']
        amendment['amends_amendment_id'] = doc['amends_amendment']['amendment_id']
        if amended_amendment = Utils.amendment_for(doc['amends_amendment']['amendment_id'])
          amendment['amends_amendment'] = amended_amendment
        else
          missing_amendments << {amendment_id: amendment_id, amended_amendment_id: doc['amends_amendment']['amendment_id']}
        end
      end

      amendment.save!
      count += 1
      puts "[#{amendment_id}] Saved" if options[:debug]
    end

    if missing_committees.any?
      missing_committees = missing_committees.uniq
      Report.warning self, "Found #{missing_committees.size} missing committees by name.", {missing_committees: missing_committees}
    end

    if missing_bills.any?
      Report.warning self, "Found #{missing_bills.size} missing bills", {missing_bills: missing_bills}
    end

    if missing_amendments.any?
      Report.warning self, "Found #{missing_amendments.size} missing amendments", {missing_amendments: missing_amendments}
    end

    if bad_amendments.any?
      Report.failure self, "Failed to save #{bad_amendments.size} amendments.", {last_bad_amendment: bad_amendments.last}
    end

    Report.success self, "Synced #{count} amendments for congress ##{congress} from GovTrack.us."
  end

  # only amendments can be sponsored by committees
  def self.sponsor_committee_for(sponsor)
    committee_id, subcommittee_id = sponsor['committee_id'].scan(/^([a-zA-Z]+)(\d+)$/).first
    committee_id = committee_id.upcase

    criteria = {committee_id: committee_id}
    criteria[:subcommittee_id] = subcommittee_id unless subcommittee_id == "00"

    if committee = Committee.where(criteria).first
      Utils.committee_for committee
    else
      nil
    end
  end
end