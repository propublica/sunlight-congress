class FloorUpdate
  include Mongoid::Document
  
  field :chamber
  field :legislative_day
  
  def self.order_keys
    [:timestamp, :legislative_day]
  end
  
  def self.singular_api?
    false
  end
  
  def self.basic_fields
    [:chamber, :legislative_day, :timestamp, :events]
  end
  
end