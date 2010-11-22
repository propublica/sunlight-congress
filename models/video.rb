class Video
  include Mongoid::Document
  
  index :timestamp_id, :unique => true
  
  # timestamp_id is stored as a String
  field :timestamp_id, :type => String
  
  def self.unique_keys
    [:timestamp_id]
  end
  
  def self.default_order
    :timestamp_id
  end
  
  def self.basic_fields
    [:duration, :legislative_day, :timestamp_id, :clip_urls]
  end
end