class UpcomingBill
  include Mongoid::Document
  include Mongoid::Timestamps
  
  include ::Queryable::Model
  
  default_order :legislative_day
  
  basic_fields :chamber, :session, :legislative_day, :bill_id, :source_url, :source_type, :context, :permalink
  
  
  index chamber: 1
  index session: 1
  index legislative_day: 1
  index source_type: 1
  index bill_id: 1
  
  field :legislative_day
end