class Clip
  include Api::Model
  publicly :searchable

  basic_fields :video_id, :id, :video_clip_id, :offset, :duration,
    :legislator_names, :rolls, :bills, :bioguide_ids, :events, :srt_link

  search_fields :events, :captions, :legislator_names
end