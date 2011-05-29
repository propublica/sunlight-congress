class CommitteeHearing
  
  include Queryable::Model
  
  default_order :occurs_at
  
  basic_fields :chamber, :committee_id, :occurs_at, :description, :room
  
  search_fields :description
  
  
  include Mongoid::Document
  include Mongoid::Timestamps
  
  index :chamber
  index :committee_id
  index :occurs_at
  
  field :legislative_day
end