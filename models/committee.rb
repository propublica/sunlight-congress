class Committee
  include Mongoid::Document
  include Mongoid::Timestamps
  
  index :committee_id, :unique => true
  index :chamber
  
  validates_presence_of :committee_id
  validates_presence_of :chamber
end