class UpcomingBill
  include Api::Model
  publicly :queryable

  basic_fields :chamber, :session, :legislative_day, :bill_id, 
    :source_url, :source_type, :context, :permalink

  search_fields :context


  include Mongoid::Document
  include Mongoid::Timestamps
  
  index chamber: 1
  index session: 1
  index legislative_day: 1
  index source_type: 1
  index bill_id: 1
  
  field :legislative_day
end