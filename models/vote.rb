class Vote
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :roll_id
  field :chamber
  field :session
  field :result
  field :number
  field :bill_id
  field :roll_type
  field :required
  field :question
  
  index :roll_id
  index :chamber
  index :session
  index :type
  index :result
  index :voted_at
  index :roll_type
  index :bill_id
  
  validates_presence_of :roll_id
  validates_presence_of :chamber
  validates_presence_of :session
  validates_presence_of :result
  
  
  def self.unique_keys
    [:roll_id]
  end
  
  def self.default_order
    :voted_at
  end
  
  def self.basic_fields
    [:how, :roll_id, :number, :year, :chamber, :session, :result, :bill_id, :voted_at, :last_updated, :roll_type,  :question, :required, :vote_breakdown]
  end
  
end