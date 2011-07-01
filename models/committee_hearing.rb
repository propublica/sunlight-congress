class CommitteeHearing
  
  include Queryable::Model
  
  default_order :occurs_at
  
  basic_fields :session, :chamber, :committee_id, :occurs_at, :description, :room, :legislative_day, :time_of_day
  
  search_fields :description
  
  
  include Mongoid::Document
  include Mongoid::Timestamps
  
  index :chamber
  index :committee_id
  index :occurs_at
  
  field :legislative_day
end