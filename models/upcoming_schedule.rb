class UpcomingSchedule
  
  include Queryable::Model
  
  default_order :legislative_day
  
  basic_fields :chamber, :session, :legislative_day, :bill_ids, :source_url, :source_type, :permalink
  
  
  include Mongoid::Document
  include Mongoid::Timestamps
  
  index :chamber
  index :session
  index :legislative_day
  index :source_type
  index :bill_ids
  
  field :legislative_day
end