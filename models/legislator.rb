class Legislator
  include Api::Model
  publicly :queryable, :searchable

  basic_fields  :bioguide_id, :thomas_id, :lis_id, :fec_ids,
      :votesmart_id, :crp_id, :govtrack_id,
      :title, :first_name, :nickname, :middle_name, :last_name, :name_suffix, 
      :other_names, :gender, :in_office,
      :state, :party, :chamber, :district,
      :phone, :office, :website, :contact_form,
      :twitter_id, :facebook_id, :youtube_id

  search_fields :first_name, :last_name, :middle_name, :nickname, "other_names.last"


  include Mongoid::Document
  include Mongoid::Timestamps

  index in_office: 1

  index bioguide_id: 1
  index govtrack_id: 1
  index thomas_id: 1
  index votesmart_id: 1
  index crp_id: 1
  index lis_id: 1
  index fec_ids: 1

  index chamber: 1
  index title: 1
  index state: 1
  index district: 1
  index party: 1
  index gender: 1

  index first_name: 1
  index last_name: 1
  index nickname: 1
  index middle_name: 1
  index name_suffix: 1

  index term_start: 1
  index term_end: 1
end