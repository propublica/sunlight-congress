class Clip
  include Api::Model
  publicly :searchable

  basic_fields :video_id, :clip_id, :video_clip_id, 
    :events, :published_at,
    :offset, :duration, :srt_link,
    :legislator_names, 
    :roll_ids, :bill_ids, :legislator_ids

  search_fields :events, :captions, :legislator_names
end