class Video
  include Mongoid::Document
  
  field :legislative_day
  field :timestamp_id
  field :duration, :type => Integer
  field "clips.duration", :type => Integer
  
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