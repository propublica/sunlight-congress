class Clip

  include Searchable::Model
  
  result_fields :video_id, :id, :video_clip_id, :offset, :duration, :events
  searchable_fields :events

end