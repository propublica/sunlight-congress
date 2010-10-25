class Vote
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :roll_id
  field :chamber
  field :session
  field :result
  
  index :roll_id
  index :chamber
  index :session
  index :type
  index :result
  index :voted_at
  index :type
  index :bill_id
  
  validates_presence_of :roll_id
  validates_presence_of :chamber
  validates_presence_of :session
  validates_presence_of :result
  
  
  def self.unique_keys
    [:roll_id]
  end
  
  def self.filter_keys
    {
      :session => String,
      :chamber => String, 
      :bill_id => String,
      :type => String
    }
  end
  
  def self.order_keys
    [:voted_at]
  end
  
  def self.basic_fields
    [:roll_id, :number, :year, :chamber, :session, :result, :bill_id, :voted_at, :last_updated, :type, :question, :required, :vote_breakdown]
  end
  
end