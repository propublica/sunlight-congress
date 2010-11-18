class FloorUpdate
  include Mongoid::Document
  
  field :chamber
  field :legislative_day
  
  def self.default_order
    :timestamp
  end
  
  def self.singular_api?
    false
  end
  
  def self.basic_fields
    [:chamber, :legislative_day, :timestamp, :events]
  end
  
end