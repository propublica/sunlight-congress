class Video
  include Mongoid::Document
  
  def self.unique_keys
    [:timestamp_id]
  end
  
  def self.filter_keys
    {
      :legislative_day => String,
      :timestamp_id => String
    }
  end
  
  def self.order_keys
    [:legislative_day]
  end
  
  def self.basic_fields
    [:duration, :clip_id, :legislative_day, :timestamp_id, :clip_urls]
  end
end