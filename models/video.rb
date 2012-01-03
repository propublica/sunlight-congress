class Video
  
  include Queryable::Model
  
  default_order :pubdate
  basic_fields :duration, :legislative_day, :video_id, :clip_urls, :pubdate, :chamber, :legislator_names, :bioguide_ids, :bills, :clip_id, :session, :rolls
  search_fields "clips.events"
  
  
  include Mongoid::Document
  
  index :video_id
  index :clip_id
  index :chamber
  index :legislative_day
  index :pubdate
  index :bills
  index :rolls
  index :legislator_names
  index :bioguide_ids
  index :"clips.bills"
  index :"clips.legislator_names"
  index :"clips.bioguide_ids"
  
  field :legislative_day
end
