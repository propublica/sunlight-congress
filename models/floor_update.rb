class FloorUpdate
  include Mongoid::Document
  
  index :chamber
  index :legislative_day
  
  def self.default_order
    :timestamp
  end
  
  def self.basic_fields
    [:chamber, :legislative_day, :timestamp, :events]
  end
  
  def self.search_fields
    [:events]
  end
  
end