class Video
  
  include Queryable::Model
  
  default_order :pubdate
  
  basic_fields :duration, :legislative_day, :video_id, :clip_urls, :status, :pubdate, :category, :title, :description, :chamber, :start_time
  
  search_fields "clips.events", :title, :description
  
  
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
  
  field :legislative_day
end
