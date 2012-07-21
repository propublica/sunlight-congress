class Committee
  include Mongoid::Document
  include Mongoid::Timestamps
  
  index({committee_id: 1}, {unique: true})
  index chamber: 1
  
  validates_presence_of :committee_id
  validates_presence_of :chamber
end