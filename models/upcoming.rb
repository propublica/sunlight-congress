class Upcoming
  
  include Queryable::Model
  
  default_order :legislative_day
  
  basic_fields :chamber, :session, :legislative_day, :upcoming_type, :bill_id, :source_url, :source_type, :context
  
  include Mongoid::Document
  include Mongoid::Timestamps
  
  index :chamber
  index :session
  index :legislative_day
  index :upcoming_type
  index :source
  
  field :legislative_day
  
  # for upcoming_type "bill"
  index :bill_id
  
  # for upcoming_type "schedule"
  index :bill_ids
  
end