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
    
    # sorting is necessary ensures amendments which  
    # amend prior amendments can find them
    amendment_ids.sort!

    amendment_ids.each do |amendment_id|
      amendment = Bill.find_or_initialize_by amendment_id: amendment_id
      
      type, number, congress, chamber = Utils.amendment_fields_from amendment_id

      path = "data/unitedstates/congress/#{congress}/amendments/#{type}/#{type}#{number}/data.json"
      doc = Oj.load open(path)
      
      # not sure how to tell the difference between these yet
      offered_on = Utils.utc_parse(doc['offered_at']) if doc['offered_at']
      proposed_on = Utils.utc_parse(doc['proposed_at']) if doc['proposed_at']
      submitted_on = Utils.utc_parse(doc['submitted_at']) if doc['submitted_at']
      
      actions = Bills.actions_for doc['actions']
      
      amendment.attributes = {
        document_type: "amendment",
        document_id: amendment_id,

        congress: congress,
        number: number,
        chamber: chamber,

        offered_on: offered_on,
        proposed_on: proposed_on,
        submitted_on: submitted_on,
        
        title: doc['title'],
        purpose: doc['purpose'],
        description: doc['description'],
        
        actions: actions,
        last_action: actions.last,
        last_action_at: actions.last ? actions.last['acted_at'] : nil
      }
      
      # if sponsor
      #   amendment.attributes = {
      #     sponsor: sponsor,
      #     sponsor_type: sponsor_type,
      #     sponsor_id: sponsor_id
      #   }
      # end

      # sponsor_type = sponsor_type_for doc
      # if sponsor_type == 'legislator'
      #   sponsor = sponsor_for amendment_id, doc, legislators, missing_ids
      #   sponsor_id = sponsor['bioguide_id'] # ?
      # else
      #   sponsor = sponsor_committee_for amendment_id, doc, chamber, missing_committees
      #   sponsor_id = sponsor[:committee_id] # ?
      # end
      
      # if bill_id
      #   if bill = Utils.bill_for(bill_id)
      #     amendment.attributes = {
      #       bill_id: bill_id,
      #       bill: bill
      #     }

      #     if bill_sequence
      #       amendment[:bill_sequence] = bill_sequence
      #     end
      #   else
      #     Report.warning self, "[#{amendment_id}] Found bill_id #{bill_id}, but couldn't find bill."
      #   end
      # end
      
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
      Report.warning self, "Found #{missing_bills.size} missing bills", missing_bills
    end

    if missing_amendments.any?
      Report.warning self, "Found #{missing_amendments.size} missing amendments", missing_amendments
    end
    
    if bad_amendments.any?
      Report.failure self, "Failed to save #{bad_amendments.size} amendments.", amendment: bad_amendments.last
    end
    
    Report.success self, "Synced #{count} amendments for congress ##{congress} from GovTrack.us."
  end
  
  def self.sponsor_type_for(doc)
    sponsor = doc.at :sponsor
    if sponsor['id']
      'legislator'
    elsif sponsor['committee']
      'committee'
    end
  end
  
  def self.sponsor_for(amendment_id, doc, legislators, missing_ids)
    sponsor = doc.at :sponsor
    if legislators[sponsor['id']]
      legislators[sponsor['id']]
    else
      missing_ids << [sponsor['id'], amendment_id]
      nil
    end
  end
  
  def self.sponsor_committee_for(amendment_id, doc, chamber, missing_committees)
    name = doc.at(:sponsor)['committee']
    chamber = chamber.capitalize
    full_name = name.sub /^#{chamber}/, "#{chamber} Committee on"
    if committee = Committee.where(name: full_name).first
      Utils.committee_for committee
    else
      missing_committees << [name, amendment_id]
      nil
    end
  end
  
  def self.actions_for(doc)
    
  end

end