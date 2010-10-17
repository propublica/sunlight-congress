class Bill
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :bill_id
  field :bill_type
  field :code
  field :chamber
  field :session
  field :state
  
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
  
  
  def self.unique_keys
    [:bill_id]
  end
  
  def self.filter_keys
    {
      :session => String,
      :chamber => String,
      :sponsor_id => String, 
      :cosponsor_ids => String, 
      :bill_type => String,
      :state => String,
      :house_result => String,
      :senate_result => String,
      :passed => Boolean,
      :vetoed => Boolean,
      :override_house_result => String,
      :override_senate_result => String,
      :awaiting_signature => Boolean,
      :enacted => Boolean
    }
  end
  
  def self.basic_fields
    [
      :bill_id, :bill_type, :code, :number, :session, :chamber, :last_updated, :state, 
      :short_title, :official_title, :popular_title,
      :sponsor_id, :cosponsors_count, :votes_count, :last_action_at, :last_vote_at, 
      :introduced_at, :house_result, :house_result_at, :senate_result, :senate_result_at, :passed, :passed_at,
      :vetoed, :vetoed_at, :override_house_result, :override_house_result_at,
      :override_senate_result, :override_senate_result_at, 
      :awaiting_signature, :awaiting_signature_since, :enacted, :enacted_at
    ]
  end
  
  def self.order_keys
    [
      :introduced_at, :last_vote_at, :last_action_at, 
      :passed_at, :vetoed_at, :override_house_result_at, 
      :override_senate_result_at, :awaiting_signature_since, :enacted_at
    ]
  end
  
end