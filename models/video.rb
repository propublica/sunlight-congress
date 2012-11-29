class Video
  include Api::Model
  publicly :queryable
    
  basic_fields :duration, :legislative_day, :video_id, 
    :clip_urls, :pubdate, :chamber, :legislator_names, 
    :bioguide_ids, :bills, :clip_id, :session, :rolls
  
  search_fields "clips.events"
  


  include Mongoid::Document
  
  index video_id: 1
  index clip_id: 1
  index chamber: 1
  index legislative_day: 1
  index pubdate: 1
  index bills: 1
  index rolls: 1
  index legislator_names: 1
  index bioguide_ids: 1
  index "clips.bills" => 1
  index "clips.legislator_names" => 1
  index "clips.bioguide_ids" => 1
  
  field :legislative_day
end