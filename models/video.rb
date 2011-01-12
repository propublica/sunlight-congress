class Video
  include Mongoid::Document
  
  index :video_id
  index :chamber
  index :legislative_day
  index :status
  index :pubdate
  index :category
  index :bills
  index :legislator_names
  index :bioguide_ids
  index :"clips.bills"
  index :"clips.legislator_names"
  index :"clips.bioguide_ids"
  
  def self.unique_keys
    [:video_id]
  end
  
  def self.default_order
    :pubdate
  end
  
  def self.basic_fields
    [:duration, :legislative_day, :video_id, :clip_urls, :status, :pubdate, :category, :title, :description, :chamber, :start_time]
  end
  
  def self.search_fields
    ["clips.events", :title, :description ]
  end
end
