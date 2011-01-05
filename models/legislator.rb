class Legislator
  include Mongoid::Document
  include Mongoid::Timestamps

  index :bioguide_id, :unique => true
  index :govtrack_id
  index :in_office
  index :chamber
  
  validates_presence_of :bioguide_id
  validates_inclusion_of :in_office, :in => [true, false]
  validates_presence_of :chamber
  
  def self.api?
    false
  end
end