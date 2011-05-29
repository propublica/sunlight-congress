class Amendment
  
  include Queryable::Model
  
  default_order :offered_at
  
  basic_fields :sponsor_id, :chamber, :number, :session, 
    :amendment_id, :state, :bill_id, :offered_at, :last_action_at, :purpose
  
  search_fields :purpose
  
  
  include Mongoid::Document
  include Mongoid::Timestamps
  
  index :amendment_id, :unique => true
  index :chamber
  index :number
  index :session
  index :bill_id
  index :offered_at
  index :last_voted_at
  index :last_action_at
  index :state
  index :sponsor_id
  index :sponsor_type
  
  field :amendment_id
  validates_uniqueness_of :amendment_id
  
end