class CommitteeHearing
  include Api::Model
  publicly :queryable
  
  basic_fields :congress, :chamber, :committee_id, :occurs_at, :description, 
    :room, :legislative_day, :time_of_day, :bill_ids, :dc, :hearing_url,
    :hearing_type, :subcommittee_name
  
  search_fields :description

  
  
  include Mongoid::Document
  include Mongoid::Timestamps
  
  index chamber: 1
  index committee_id: 1
  index occurs_at: 1
  index legislative_day: 1
  index congress: 1

  index dc: 1
  index bill_ids: 1
end