class Hearing
  include Api::Model
  publicly :queryable
  
  basic_fields :committee_id, :subcommittee_id,
    :congress, :chamber, :occurs_at, :dc,
    :room, :description, :url, 
    :bill_ids, 
    :hearing_type, :house_hearing_id # house only for now
  
  search_fields :description

  
  
  include Mongoid::Document
  include Mongoid::Timestamps
  
  index chamber: 1
  index committee_id: 1
  index subcommittee_id: 1
  index occurs_at: 1
  index congress: 1

  index dc: 1
  index bill_ids: 1
  index hearing_type: 1
end