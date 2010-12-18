class Bill
  include Mongoid::Document
  include Mongoid::Timestamps
    
  index :bill_id, :unique => true
  index :bill_type
  index :code
  index :chamber
  index :session
  index :passed
  index :enacted
  index :house_result
  index :senate_result
  index :override_house_result
  index :override_senate_result
  index :awaiting_signature
  index :sponsor_id
  index :cosponsor_ids
  index :amendments_count
  index :cosponsors_count
  
  index :introduced_at
  index :last_action_at
  index :last_vote_at
  index :passed_at
  index :awaiting_signature_since
  index :enacted_at
  
  def self.unique_keys
    [:bill_id]
  end
  
  def self.default_order
    :introduced_at
  end
  
  def self.basic_fields
    [
      :bill_id, :bill_type, :code, :number, :session, :chamber, :last_updated, :state, 
      :short_title, :official_title, :popular_title,
      :sponsor_id, :cosponsors_count, :amendments_count, :passage_votes_count, :last_action_at, :last_vote_at, 
      :introduced_at, :house_result, :house_result_at, :senate_result, :senate_result_at, :passed, :passed_at,
      :vetoed, :vetoed_at, :override_house_result, :override_house_result_at,
      :override_senate_result, :override_senate_result_at, 
      :awaiting_signature, :awaiting_signature_since, :enacted, :enacted_at
    ]
  end
  
  def self.search_fields
    [:short_title, :official_title, :popular_title, :summary, :keywords]
  end
  
end