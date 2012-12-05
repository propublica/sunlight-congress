class Video
  include Api::Model
  publicly :queryable
    
  basic_fields :video_id, :clip_id, 
    :chamber, :congress, 
    :published_at, :legislative_day, 
    :clip_urls, :duration, 
    :legislator_names,  :caption_srt_file,
    :legislator_ids, :bill_ids, :roll_ids

  include Mongoid::Document
  
  index video_id: 1
  index clip_id: 1
  index chamber: 1
  index congress: 1
  index published_at: 1
  index legislative_day: 1

  index legislator_names: 1
  index legislator_ids: 1
  index bill_ids: 1
  index roll_ids: 1
  index "clips.legislator_names" => 1
  index "clips.legislator_ids" => 1
  index "clips.bill_ids" => 1
  index "clips.roll_ids" => 1
end