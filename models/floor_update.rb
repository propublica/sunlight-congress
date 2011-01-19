class FloorUpdate
  include Mongoid::Document
  
  index :chamber
  index :legislative_day
  index :roll_ids
  index :bill_ids
  
  def self.default_order
    :timestamp
  end
  
  def self.basic_fields
    [:chamber, :legislative_day, :timestamp, :events, :roll_ids, :bill_ids]
  end
  
  def self.search_fields
    [:events]
  end
  
end