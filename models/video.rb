class Video
  include Mongoid::Document
  
  index :video_id
  index :chamber
  index :legislative_day
  index :status
  index :pubdate
  index :category
  
  def self.unique_keys
    [:timestamp_id]
  end
  
  def self.default_order
    :timestamp_id
  end
  
  def self.basic_fields
    [:duration, :legislative_day, :video_id, :clip_urls, :status, :pubdate, :category, :title, :description, :chamber, :start_time]
  end
end