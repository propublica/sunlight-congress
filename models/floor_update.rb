class FloorUpdate
  include Mongoid::Document
  
  def self.filter_keys
    {
      :chamber => String,
      :legislative_day => String
    }
  end
  
  def self.order_keys
    [:occurred_at]
  end
  
  def self.singular_api?
    false
  end
  
end