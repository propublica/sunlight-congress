class UpcomingBill
  
  include Queryable::Model
  
  default_order :legislative_day
  
  basic_fields :chamber, :session, :legislative_day, :bill_id, :source_url, :source_type, :context, :permalink
  
  
  include Mongoid::Document
  include Mongoid::Timestamps
  
  index :chamber
  index :session
  index :legislative_day
  index :source_type
  index :bill_id
  
  field :legislative_day
end