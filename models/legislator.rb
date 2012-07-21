class Legislator
  include Mongoid::Document
  include Mongoid::Timestamps

  index bioguide_id: 1
  index govtrack_id: 1
  index in_office: 1
  index chamber: 1
  
  validates_presence_of :bioguide_id
  validates_inclusion_of :in_office, :in => [true, false]
  validates_presence_of :chamber
end