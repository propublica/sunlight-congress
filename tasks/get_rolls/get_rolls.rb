require 'hpricot'

class GetRolls

  def self.run(options = {})
    session = options[:session] || Utils.current_session
    count  = 0
    missing_ids = []
    bad_rolls = []
    
    
    FileUtils.mkdir_p "data/govtrack/#{session}/rolls"
    unless system("rsync -az govtrack.us::govtrackdata/us/#{session}/rolls/ data/govtrack/#{session}/rolls/")
      Report.failure self, "Couldn't rsync to Govtrack.us."
      return
    end
    
    
    # make lookups faster later by caching a hash of legislators from which we can lookup govtrack_ids
    legislators = {}
    Legislator.only(voter_fields).all.each do |legislator|
      legislators[legislator.govtrack_id] = legislator
    end
    
    
    # Debug helpers
    rolls = Dir.glob "data/govtrack/#{session}/rolls/*.xml"
    
    # rolls = Dir.glob "data/govtrack/#{session}/rolls/h2010-165.xml"
    # rolls = rolls.first 20
    
    rolls.each do |path|
      doc = Hpricot::XML open(path)
      
      filename = File.basename path
      matches = filename.match /^([hs])(\d+)-(\d+)\.xml/
      year = matches[2]
      number = matches[3]
      
      roll_id = "#{matches[1]}#{number}-#{year}"
      
      vote = Vote.find_or_initialize_by(:roll_id => roll_id)
      
      bill_id = bill_id_for doc
      voter_ids, voters = votes_for filename, doc, legislators, missing_ids
      party_vote_breakdown = vote_breakdown_for voters
      vote_breakdown = party_vote_breakdown.delete :total
      
      vote.attributes = {
        :how => "roll",
        :chamber => doc.root['where'],
        :year => year,
        :number => number,
        :session => session,
        :result => doc.at(:result).inner_text,
        :bill_id => bill_id,
        :voted_at => Utils.govtrack_time_for(doc.root['datetime']),
        :roll_type => doc.at(:type).inner_text,
        :question => doc.at(:question).inner_text,
        :required => doc.at(:required).inner_text,
        :bill => bill_for(bill_id),
        :voter_ids => voter_ids,
        :voters => voters,
        :vote_breakdown => vote_breakdown,
        :party_vote_breakdown => party_vote_breakdown
      }
      
      if vote.save
        count += 1
        puts "[#{roll_id}] Saved successfully"
      else
        bad_rolls << {:attributes => vote.attributes, :error_messages => vote.errors.full_messages}
        puts "[#{roll_id}] Error saving, will file report"
      end
    end
    
    if bad_rolls.any?
      Report.failure self, "Failed to save #{bad_rolls.size} roll calls. Attached the last failed roll's attributes and error messages.", bad_rolls.last
    end
    
    if missing_ids.any?
      missing_ids = missing_ids.uniq
      Report.warning self, "Found #{missing_ids.size} missing GovTrack IDs, attached. Vote counts on roll calls may be inaccurate until these are fixed.", {:missing_ids => missing_ids}
    end
    
    Report.success self, "Synced #{count} roll calls for session ##{session} from GovTrack.us."
  end
  
  def self.bill_id_for(doc)
    if bill = doc.at(:bill)
      bill_id = "#{Utils.bill_type_for bill['type']}#{bill['number']}-#{bill['session']}"
    end
  end
  
  def self.bill_for(bill_id)
    bill = Bill.where(:bill_id => bill_id).only(bill_fields).first
    
    if bill
      attributes = bill.attributes
      allowed_keys = bill_fields.map {|f| f.to_s}
      attributes.keys.each {|key| attributes.delete key unless allowed_keys.include?(key)}
      attributes
    else
      nil
    end
  end
  
  def self.vote_mapping
    {
      '-' => :nays, 
      '+' => :ayes, 
      '0' => :not_voting, 
      'P' => :present
    }
  end
  
  def self.vote_breakdown_for(voters)
    breakdown = {:total => {}}
    mapping = vote_mapping
    
    voters.each do|bioguide_id, voter|      
      party = voter[:voter]['party']
      vote = mapping[voter[:vote]] || voter[:vote]
      
      breakdown[party] ||= {}
      breakdown[party][vote] ||= 0
      breakdown[:total][vote] ||= 0
      
      breakdown[party][vote] += 1
      breakdown[:total][vote] += 1
    end
    
    parties = breakdown.keys
    votes = (breakdown[:total].keys + mapping.values).uniq
    votes.each do |vote|
      parties.each do |party|
        breakdown[party][vote] ||= 0
      end
    end
    
    breakdown
  end
  
  def self.votes_for(filename, doc, legislators, missing_ids)
    voter_ids = {}
    voters = {}
    
    doc.search("//voter").each do |elem|
      vote = elem['vote']
      value = elem['value']
      govtrack_id = elem['id']
      voter = voter_for govtrack_id, legislators
      
      if voter
        bioguide_id = voter[:bioguide_id]
        voter_ids[bioguide_id] = vote
        voters[bioguide_id] = {:vote => vote, :voter => voter}
      else
        missing_ids << [govtrack_id, filename]
      end
    end
    
    [voter_ids, voters]
  end
  
  def self.voter_for(govtrack_id, legislators)
    legislator = legislators[govtrack_id]
    
    if legislator
      attributes = legislator.attributes
      allowed_keys = voter_fields.map {|f| f.to_s}
      attributes.keys.each {|key| attributes.delete key unless allowed_keys.include?(key)}
      attributes
    else
      nil
    end
  end
  
  def self.voter_fields
    [:first_name, :nickname, :last_name, :name_suffix, :title, :state, :party, :district, :govtrack_id, :bioguide_id]
  end
  
  def self.bill_fields
    Bill.basic_fields
  end
  
end