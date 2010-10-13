class Legislator
  include Mongoid::Document
  include Mongoid::Timestamps

  field :bioguide_id
  field :govtrack_id
  field :in_office, :type => Boolean
  field :chamber
  
  index :bioguide_id, :unique => true
  index :govtrack_id, :unique => true
  index :in_office
  index :chamber
  
  
end