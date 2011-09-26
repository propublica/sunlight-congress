class FloorUpdate

  include Queryable::Model
  
  default_order :timestamp
  
  basic_fields :chamber, :legislative_day, :timestamp, 
    :events, :roll_ids, :bill_ids, :legislator_ids, :session
  
  search_fields :events
  
  
  include Mongoid::Document
  
  index :chamber
  index :legislative_day
  index :roll_ids
  index :bill_ids
  index :legislator_ids
  index :timestamp
  index :session
  
  field :legislative_day
end