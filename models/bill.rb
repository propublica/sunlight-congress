class Bill
  
  # searchable behavior
  
  include Searchable::Model
  
  result_fields :bill_id, :bill_type, :code, :number, :session, :chamber, 
    :short_title, :official_title, :popular_title,
    :sponsor_id, :cosponsors_count, :amendments_count, :passage_votes_count, :last_action_at, :last_passage_vote_at, :abbreviated,
    :introduced_at, :house_passage_result, :house_passage_result_at, :senate_passage_result, :senate_passage_result_at, 
    :vetoed, :vetoed_at, :house_override_result, :house_override_result_at,
    :senate_override_result, :senate_override_result_at, 
    :awaiting_signature, :awaiting_signature_since, :enacted, :enacted_at,
    :sponsor, :last_action,
    :versions_count,
    :last_version, :last_version_on,
    :nicknames
  
  searchable_fields :versions, :summary, :keywords, :popular_title, :official_title, :short_title, :nicknames
  
  
  # queryable behavior
  
  include Queryable::Model
  
  default_order :introduced_at
  
  basic_fields :bill_id, :bill_type, :code, :number, :session, :chamber, 
    :short_title, :official_title, :popular_title,
    :sponsor_id, :cosponsors_count, :amendments_count, :passage_votes_count, :last_action_at, :last_passage_vote_at, :abbreviated,
    :introduced_at, :house_passage_result, :house_passage_result_at, :senate_passage_result, :senate_passage_result_at, 
    :vetoed, :vetoed_at, :house_override_result, :house_override_result_at,
    :senate_override_result, :senate_override_result_at, 
    :awaiting_signature, :awaiting_signature_since, :enacted, :enacted_at,
    :last_version_on, :nicknames

  search_fields :short_title, :official_title, :popular_title, :summary, :keywords, :nicknames
  
  
  # MongoDB behavior
  
  include Mongoid::Document
  include Mongoid::Timestamps
  
  index :bill_id
  index :bill_type
  index :code
  index :chamber
  index :session

  index :nicknames
  
  index :sponsor_id
  index :cosponsor_ids
  index :amendments_count
  index :cosponsors_count
  index :keywords
  index :committee_ids
  index :last_action_at
  index :last_passage_vote_at
  
  index :introduced_at
  index :house_passage_result
  index :house_passage_result_at
  index :senate_passage_result
  index :senate_passage_result_at
  index :house_override_result
  index :house_override_result_at
  index :senate_override_result
  index :senate_override_result_at
  index :awaiting_signature
  index :awaiting_signature_since
  index :enacted
  index :enacted_at

  index :usc_extracted_ids
  
  index :last_version_on
  
  index :abbreviated

  # spell out YYYY-MM-DD fields as strings
  field :last_version_on
end