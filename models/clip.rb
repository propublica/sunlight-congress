class Clip

  include ::Searchable::Model
  
  result_fields :video_id, :id, :video_clip_id, :offset, :duration, :events, :srt_link, :legislator_names, :rolls, :bills, :bioguide_ids
  searchable_fields :events, :captions, :legislator_names

end