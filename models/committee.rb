class Committee
  include Mongoid::Document
  include Mongoid::Timestamps
  
  index({committee_id: 1}, {unique: true})
  index chamber: 1
  
  validates_presence_of :committee_id
  validates_presence_of :chamber


  include Queryable::Model

  default_order :created_at
  basic_fields :committee_id, :name, :chamber
  search_fields :name
end