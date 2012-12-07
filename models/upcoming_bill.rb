class UpcomingBill
  include Api::Model
  publicly :queryable

  basic_fields :bill_id, :source_type, :url,
    :chamber, :congress, :legislative_day, 
    :context # senate-only

  search_fields :context


  include Mongoid::Document
  include Mongoid::Timestamps
  
  index chamber: 1
  index congress: 1
  index legislative_day: 1
  index source_type: 1
  index bill_id: 1
end