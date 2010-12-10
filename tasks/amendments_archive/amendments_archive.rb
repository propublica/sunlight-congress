require 'nokogiri'

class AmendmentsArchive
  
  def self.run(options = {})
    session = options[:session] || Utils.current_session
    count = 0
    missing_ids = []
    bad_amendments = []
    
    FileUtils.mkdir_p "data/govtrack/#{session}/amendments"
    unless system("rsync -az govtrack.us::govtrackdata/us/#{session}/bills.amdt/ data/govtrack/#{session}/amendments/")
      Report.failure self, "Couldn't rsync to Govtrack.us."
      return
    end
    
    
    legislators = {}
    Legislator.only(Utils.legislator_fields).all.each do |legislator|
      legislators[legislator.govtrack_id] = Utils.legislator_for legislator
    end
    
    amendments = Dir.glob "data/govtrack/#{session}/amendments/*.xml"
    
    # debug helpers
    # amendments = Dir.glob "data/govtrack/#{session}/bills/h2109.xml"
    # amendments = amendments.first 20
    
    amendments.each do |path|
      doc = Nokogiri::XML open(path)
      
      filename = File.basename path
      
      number = doc.root.attributes['number'].text.to_i
      chamber_type = doc.root['chamber']
      chamber = {'h' => 'house', 's' => 'senate'}[chamber_type]
      amendment_id = "#{chamber_type}#{number}-#{session}"
      
      bill_id = bill_id_for doc, session
      
      sponsor_type = sponsor_type_for doc
      sponsor = nil
      if sponsor_type == 'legislator'
        sponsor = sponsor_for filename, doc, legislators, missing_ids
      else
        sponsor = doc.at(:sponsor)['committee']
      end
      
      # actions = actions_for doc
      state = state_for doc
      
      # last_action_at = actions.last ? actions.last[:acted_at] : nil
      offered_at = Utils.govtrack_time_for doc.at(:offered)['datetime']
      
      amendment = Amendment.find_or_initialize_by :amendment_id => amendment_id
      amendment.attributes = {
        :session => session,
        :number => number,
        :chamber => chamber,
        :state => state,
        :offered_at => offered_at
        
        # :actions => actions,
        # :last_action_at => last_action_at
      }
      
      if sponsor
        amendment.attributes = {
          :sponsor => sponsor,
          :sponsor_type => sponsor_type
        }
        if sponsor_type == 'legislator'
          amendment.attributes = {:sponsor_id => sponsor[:bioguide_id]}
        end
      end
      
      if bill_id
        if bill = Utils.bill_for(bill_id)
          amendment.attributes = {
            :bill_id => bill_id,
            :bill => bill
          }
        else
          Report.warning self, "[#{amendment_id}] Found bill_id #{bill_id}, but couldn't find bill."
        end
      end
      
      
      if amendment.save
        count += 1
        puts "[#{amendment_id}] Saved successfully"
        
        # update bill, should be no validation issues
        if bill_id
          bill = Bill.where(:bill_id => bill_id).first
          bill[:amendments] << Utils.amendment_for(amendment)
          bill[:amendment_ids] << amendment_id
          bill.save!
        end
        
      else
        bad_amendments << {:attributes => amendment.attributes, :error_messages => amendment.errors.full_messages}
        puts "[#{amendment_id}] Error saving, will file report"
      end
    end
    
    if missing_ids.any?
      missing_ids = missing_ids.uniq
      Report.warning self, "Found #{missing_ids.size} missing GovTrack IDs, attached.", {:missing_ids => missing_ids}
    end
    
    if bad_amendments.any?
      Report.failure self, "Failed to save #{bad_amendments.size} amendments. Attached the last failed amendment's attributes and errors.", :amendment => bad_amendments.last
    end
    
    Report.success self, "Synced #{count} amendments for session ##{session} from GovTrack.us."
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
  
  def self.bill_id_for(doc, session)
    elem = doc.at :amends
    number = elem['number']
    type = Utils.bill_type_for elem['type']
    if number and type
      "#{type}#{number}-#{session}"
    else
      nil
    end
  end
  
  def self.actions_for(doc)
#     doc.search('//actions/*').reject {|a| a.class == Hpricot::Text}.map do |action|
#       {
#         :acted_at => Utils.govtrack_time_for(action['datetime']),
#         :text => (action/:text).inner_text,
#         :type => action.name
#       }
#     end
  end

end