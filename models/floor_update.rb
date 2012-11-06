class FloorUpdate

  include ::Queryable::Model
  
  default_order :timestamp
  
  basic_fields :chamber, :legislative_day, :timestamp, 
    :events, :roll_ids, :bill_ids, :legislator_ids, :session
  
  search_fields :events
  
  
  include Mongoid::Document
  
  index chamber: 1
  index legislative_day: 1
  index roll_ids: 1
  index bill_ids: 1
  index legislator_ids: 1
  index timestamp: 1
  index session: 1
  
  field :legislative_day
end