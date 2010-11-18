class Bill
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :bill_id
  field :bill_type
  field :code
  field :chamber
  field :session, :type => Integer
  field :number, :type => Integer
  field :state
  
  field :sponsor_id, :type => Array
  field :cosponsor_ids, :type => Array
  
  field :house_result
  field :senate_result
  field :override_house_result
  field :override_senate_result
  field :passed, :type => Boolean
  field :vetoed, :type => Boolean
  field :awaiting_signature, :type => Boolean
  field :enacted, :type => Boolean
  field :cosponsors_count, :type => Integer
  field :passage_votes_count, :type => Integer
  
  field "last_action.type"
  field "last_action.text"
  field "last_action.acted_at"
  
  
  index :bill_id
  index :bill_type
  index :code
  index :chamber
  index :session
  index :introduced_at
  index :sponsor_id
  index :cosponsor_ids
  index :keywords
  index :last_action_at
  index :last_vote_at
  index :enacted_at
  index :enacted
  
  validates_presence_of :bill_id
  validates_presence_of :bill_type
  validates_presence_of :code
  validates_presence_of :chamber
  validates_presence_of :session
  validates_presence_of :state
  
  field "last_action.type", :type => String
  
  def self.unique_keys
    [:bill_id]
  end
  
  def self.basic_fields
    [
      :bill_id, :bill_type, :code, :number, :session, :chamber, :last_updated, :state, 
      :short_title, :official_title, :popular_title,
      :sponsor_id, :cosponsors_count, :passage_votes_count, :last_action_at, :last_vote_at, 
      :introduced_at, :house_result, :house_result_at, :senate_result, :senate_result_at, :passed, :passed_at,
      :vetoed, :vetoed_at, :override_house_result, :override_house_result_at,
      :override_senate_result, :override_senate_result_at, 
      :awaiting_signature, :awaiting_signature_since, :enacted, :enacted_at
    ]
  end
  
  def self.default_order
    :introduced_at
  end
  
end