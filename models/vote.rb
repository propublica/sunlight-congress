class Vote
  
  include Queryable::Model
  
  default_order :voted_at
  
  basic_fields :how, :roll_id, :number, :year, :chamber, :session, 
    :result, :bill_id, :voted_at, :last_updated, :roll_type,  :question, 
    :required, :vote_type, :passage_type, :amendment_id, :vote_breakdown
  
  search_fields :question
  
  
  include Mongoid::Document
  include Mongoid::Timestamps
  
  index :roll_id
  index :chamber
  index :session
  index :type
  index :result
  index :voted_at
  index :roll_type
  index :vote_type
  index :passage_type
  index :required
  index :year
  index :number
  index :how
  index :bill_id
  index :amendment_id
  
  field :roll_id
  validates_uniqueness_of :roll_id, :allow_nil => true
end