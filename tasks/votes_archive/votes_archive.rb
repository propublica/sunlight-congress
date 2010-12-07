require 'hpricot'

class VotesArchive

  def self.run(options = {})
    options[:session] ||= Utils.current_session
    
    get_rolls options
    sort_passage_votes options
  end
  
  def self.get_rolls(options)
    session = options[:session]
    
    count = 0
    missing_ids = []
    bad_rolls = []
    
    
    FileUtils.mkdir_p "data/govtrack/#{session}/rolls"
    unless system("rsync -az govtrack.us::govtrackdata/us/#{session}/rolls/ data/govtrack/#{session}/rolls/")
      Report.failure self, "Couldn't rsync to Govtrack.us."
      return
    end
    
    
    # make lookups faster later by caching a hash of legislators from which we can lookup govtrack_ids
    legislators = {}
    Legislator.only(Utils.voter_fields).all.each do |legislator|
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
      year = matches[2].to_i
      number = matches[3].to_i
      
      roll_id = "#{matches[1]}#{number}-#{year}"
      
      vote = Vote.find_or_initialize_by(:roll_id => roll_id)
      
      bill_id = bill_id_for doc
      voter_ids, voters = votes_for filename, doc, legislators, missing_ids
      party_vote_breakdown = Utils.vote_breakdown_for voters
      vote_breakdown = party_vote_breakdown.delete :total
      
      roll_type = doc.at(:type).inner_text
      vote_type = vote_type_for roll_type
      
      vote.attributes = {
        :vote_type => vote_type,
        :how => "roll",
        :chamber => doc.root['where'],
        :year => year,
        :number => number,
        :session => session,
        :result => doc.at(:result).inner_text,
        :bill_id => bill_id,
        :voted_at => Utils.govtrack_time_for(doc.root['datetime']),
        :roll_type => roll_type,
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
        # puts "[#{roll_id}] Saved successfully"
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
  
  def self.sort_passage_votes(options)
    session = options[:session]
    
    roll_count = 0
    voice_count = 0
    bad_votes = []
    
    missing_rolls = []
    
    bills = Bill.where(:session => session, :passage_votes_count => {"$gte" => 1}).all
    # bills = bills.to_a.first 20
    
    bills.each do |bill|
      
      # clear out old voice votes for this bill, since there is no unique ID to update them by
      Vote.where(:bill_id => bill.bill_id, :how => {"$ne" => "roll"}).all.each {|v| v.delete}
      
      bill.passage_votes.each do |vote|
        if vote['how'] == 'roll'
          
          # if the roll has been entered into the system already, mark it as a passage vote
          # otherwise, don't bother creating it here, we don't have enough information
          roll = Vote.where(:roll_id => vote['roll_id']).first
          
          if roll
            roll[:vote_type] = "passage"
            roll[:passage_type] = vote['passage_type']
            roll.save!
            
            roll_count += 1
            # puts "[#{bill.bill_id}] Updated roll call #{roll.roll_id} to mark as a passage vote"
          else
            missing_rolls << {:bill_id => bill.bill_id, :roll_id => vote['roll_id']}
            puts "[#{bill.bill_id} Couldn't find roll call #{vote['roll_id']} mentioned in passage votes list for #{bill.bill_id}"
          end
        else
          
          attributes = {
            :bill_id => bill.bill_id,
            :session => session,
            :year => vote['voted_at'].year,
            
            :bill => bill_for(bill.bill_id), # reusing the method standardizes on columns, worth the extra call
            
            :how => vote['how'],
            :result => vote['result'],
            :voted_at => vote['voted_at'],
            :text => vote['text'],
            :chamber => vote['chamber'],
            
            :passage_type => vote['passage_type'],
            :vote_type => "passage"
          }
          
          vote = Vote.new attributes
          
          if vote.save
            voice_count += 1
            # puts "[#{bill.bill_id}] Added a voice vote"
          else
            bad_votes << {:attributes => attributes, :error_messages => vote.errors.full_messages}
            puts "[#{bill.bill_id}] Bad voice vote, logging"
          end
        end
      end
    end
    
    if bad_votes.any?
      Report.failure self, "Failed to save #{bad_votes.size} voice votes. Attached the last failed vote's attributes and error messages.", bad_votes.last
    end
    
    if missing_rolls.any?
      Report.warning self, "Found #{missing_rolls.size} roll calls mentioned in a passage votes array whose corresponding Vote object was not found", :missing_rolls => missing_rolls
    end
    
    Report.success self, "Updated #{roll_count} roll call and #{voice_count} voice passage votes"
  end
  
  # I think we can reliably say cloture and nomination, 
  # since the Senate does a good job of keeping the roll call types to a small set, 
  # and both of these kind of votes only occur in the Senate.
  #
  # "passage" will get set in the part of the task dedicated to going back over each bill and looking at its passage votes.
  # Such votes will be automatically be labeled "other" between the execution of this method and that one.
  def self.vote_type_for(roll_type)
    if roll_type =~ /cloture/i 
      "cloture"
    elsif roll_type == "On the Nomination"
      "nomination"
    else
      "other"
    end
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
        if govtrack_id.to_i == 0
          missing_ids << [govtrack_id, filename]
        else
          missing_ids << govtrack_id
        end
      end
    end
    
    [voter_ids, voters]
  end
  
  def self.voter_for(govtrack_id, legislators)
    legislator = legislators[govtrack_id]
    
    if legislator
      attributes = legislator.attributes
      allowed_keys = Utils.voter_fields.map {|f| f.to_s}
      attributes.keys.each {|key| attributes.delete key unless allowed_keys.include?(key)}
      attributes
    else
      nil
    end
  end
  
  def self.bill_fields
    Bill.basic_fields
  end
  
end