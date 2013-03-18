class UpcomingBill
  include Api::Model
  publicly :queryable

  basic_fields :bill_id, 
    :range, :legislative_day, 
    :chamber, :congress, 
    :source_type, :url,
    :context # senate-only


  include Mongoid::Document
  include Mongoid::Timestamps
  
  index chamber: 1
  index congress: 1
  index legislative_day: 1
  index source_type: 1
  index bill_id: 1
  index range: 1

  # support an orderly ordering of upcoming bills
  index({legislative_day: 1, range: 1})
end