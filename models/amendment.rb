class Amendment
  
  include ::Queryable::Model
  
  default_order :offered_at
  
  basic_fields :sponsor_id, :chamber, :number, :session, 
    :amendment_id, :state, :bill_id, :offered_at, :last_action_at, :purpose
  
  search_fields :purpose
  
  
  include Mongoid::Document
  include Mongoid::Timestamps
  
  index({amendment_id: 1}, {unique: true})
  index chamber: 1
  index number: 1
  index session: 1
  index bill_id: 1
  index offered_at: 1
  index last_voted_at: 1
  index last_action_at: 1
  index state: 1
  index sponsor_id: 1
  index sponsor_type: 1
  
  field :amendment_id
  validates_uniqueness_of :amendment_id
end