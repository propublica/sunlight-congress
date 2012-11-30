require 'nokogiri'

class AmendmentsArchive
  
  def self.run(options = {})
    options[:session] = (options[:session] ? options[:session].to_i : Utils.current_session)
    load_amendments options
    update_bills options
  end
  
  def self.load_amendments(options)
    session = options[:session]
    count = 0
    
    missing_ids = []
    missing_committees = []
    bad_amendments = []
    
    FileUtils.mkdir_p "data/govtrack/#{session}/amendments"
    unless system("rsync -az govtrack.us::govtrackdata/us/#{session}/bills.amdt/ data/govtrack/#{session}/amendments/")
      Report.failure self, "Couldn't rsync to Govtrack.us."
      return
    end
    
    
    legislators = {}
    Legislator.where(govtrack_id: {"$exists" => true}).only(Legislator.basic_fields).each do |legislator|
      legislators[legislator.govtrack_id] = Utils.legislator_for legislator
    end
    
    amendments = Dir.glob "data/govtrack/#{session}/amendments/*.xml"
    
    # debug helpers
    # amendments = Dir.glob "data/govtrack/111/amendments/h541.xml"
    # amendments = amendments.first 20

    if options[:limit]
      amendments = amendments.first options[:limit].to_i
    end
    
    amendments.each do |path|
      doc = Nokogiri::XML open(path)
      
      filename = File.basename path
      
      number = doc.root.attributes['number'].text.to_i
      chamber_type = doc.root['chamber']
      chamber = {'h' => 'house', 's' => 'senate'}[chamber_type]
      amendment_id = "#{chamber_type}#{number}-#{session}"
      state = state_for doc
      offered_at = Utils.ensure_utc doc.at(:offered)['datetime']
      purpose = purpose_for doc
      
      bill_id = bill_id_for doc, session
      bill_sequence = bill_sequence_for doc
      
      sponsor_type = sponsor_type_for doc
      sponsor = nil
      if sponsor_type == 'legislator'
        sponsor = sponsor_for filename, doc, legislators, missing_ids
      else
        sponsor = sponsor_committee_for filename, doc, chamber, missing_committees
      end
      
      actions = actions_for doc
      last_action_at = actions.last ? actions.last[:acted_at] : nil
      
      
      amendment = Amendment.find_or_initialize_by :amendment_id => amendment_id
      amendment.attributes = {
        session: session,
        number: number,
        chamber: chamber,
        state: state,
        offered_at: offered_at,
        purpose: purpose,
        
        actions: actions,
        last_action_at: last_action_at
      }
      
      if sponsor
        amendment.attributes = {
          sponsor: sponsor,
          sponsor_type: sponsor_type,
          sponsor_id: (sponsor_type == 'legislator' ? sponsor['bioguide_id'] : sponsor[:committee_id])
        }
      end
      
      if bill_id
        if bill = Utils.bill_for(bill_id)
          amendment.attributes = {
            bill_id: bill_id,
            bill: bill
          }
          if bill_sequence
            amendment[:bill_sequence] = bill_sequence
          end
        else
          Report.warning self, "[#{amendment_id}] Found bill_id #{bill_id}, but couldn't find bill."
        end
      end
      
      
      if amendment.save
        count += 1
        # puts "[#{amendment_id}] Saved successfully"
      else
        bad_amendments << {attributes: amendment.attributes, error_messages: amendment.errors.full_messages}
        puts "[#{amendment_id}] Error saving, will file report"
      end
    end
    
    if missing_ids.any?
      missing_ids = missing_ids.uniq
      Report.warning self, "Found #{missing_ids.size} missing GovTrack IDs.", {missing_ids: missing_ids}
    end
    
    if missing_committees.any?
      missing_committees = missing_committees.uniq
      Report.warning self, "Found #{missing_committees.size} missing committees by name.", {missing_committees: missing_committees}
    end
    
    if bad_amendments.any?
      Report.failure self, "Failed to save #{bad_amendments.size} amendments.", amendment: bad_amendments.last
    end
    
    Report.success self, "Synced #{count} amendments for session ##{session} from GovTrack.us."
  end
  
  
  def self.update_bills(options)
    session = options[:session]
    
    count = 0
    amendment_count = 0
    
    bills = Bill.where(:bill_id => {"$in" => Amendment.where(:session => session).distinct(:bill_id)}).all
    # bills = bills.to_a.first 20
    
    bills.each do |bill|
      amendments = Amendment.where(:bill_id => bill.bill_id).only(Amendment.basic_fields).all.to_a.map {|amendment| Utils.amendment_for amendment}
      
      bill.attributes = {
        amendments: amendments,
        amendment_ids: amendments.map {|a| a['amendment_id']},
        amendments_count: amendments.size
      }
      
      bill.save! # should be no problem
      
      count += 1
      amendment_count += amendments.size
      
      puts "[#{bill.bill_id}] Updated with #{amendments.size} amendments" if options[:debug]
    end
    
    Report.success self, "Updated #{count} bills with #{amendment_count} amendments (out of #{Amendment.where(:session => session).count} amendments in session #{session})."
  end
  
  def self.state_for(doc)
    doc.at(:status) ? doc.at(:status).text : "unknown"
  end
  
  def self.sponsor_type_for(doc)
    sponsor = doc.at :sponsor
    if sponsor['id']
      'legislator'
    elsif sponsor['committee']
      'committee'
    end
  end
  
  def self.sponsor_for(filename, doc, legislators, missing_ids)
    sponsor = doc.at :sponsor
    if legislators[sponsor['id']]
      legislators[sponsor['id']]
    else
      missing_ids << [sponsor['id'], filename]
      nil
    end
  end
  
  def self.sponsor_committee_for(filename, doc, chamber, missing_committees)
    name = doc.at(:sponsor)['committee']
    chamber = chamber.capitalize
    full_name = name.sub /^#{chamber}/, "#{chamber} Committee on"
    if committee = Committee.where(:name => full_name).first
      Utils.committee_for committee
    else
      missing_committees << [name, filename]
      nil
    end
  end
  
  def self.bill_id_for(doc, session)
    elem = doc.at :amends
    number = elem['number']
    type = bill_type_for elem['type']
    if number and type
      "#{type}#{number}-#{session}"
    else
      nil
    end
  end
  
  def self.bill_sequence_for(doc)
    if (elem = doc.at(:amends)) and elem['sequence'].present?
      elem['sequence'].to_i
    end
  end
  
  def self.actions_for(doc)
    doc.search('//actions/*').reject {|a| a.class == Nokogiri::XML::Text}.map do |action|
      {
        :acted_at => Utils.ensure_utc(action['datetime']),
        :text => (action/:text).inner_text,
        :type => action.name
      }
    end
  end
  
  def self.purpose_for(doc)
    if elem = doc.at(:purpose) and elem.text.present?
      elem.text.strip
    else
      nil
    end
  end

  # map govtrack type to RTC type
  def self.bill_type_for(govtrack_type)
    {
      :h => 'hr',
      :hr => 'hres',
      :hj => 'hjres',
      :hc => 'hcres',
      :s => 's',
      :sr => 'sres',
      :sj => 'sjres',
      :sc => 'scres'
    }[govtrack_type.to_sym]
  end

end