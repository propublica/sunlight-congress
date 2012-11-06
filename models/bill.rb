class Bill

  # searchable behavior
  
  include ::Searchable::Model
  
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
  
  include ::Queryable::Model
  
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
  
  index bill_id: 1
  index bill_type: 1
  index code: 1
  index chamber: 1
  index session: 1

  index nicknames: 1
  
  index sponsor_id: 1
  index cosponsor_ids: 1
  index amendments_count: 1
  index cosponsors_count: 1
  index keywords: 1
  index committee_ids: 1
  index last_action_at: 1
  index last_passage_vote_at: 1
  
  index introduced_at: 1
  index house_passage_result: 1
  index house_passage_result_at: 1
  index senate_passage_result: 1
  index senate_passage_result_at: 1
  index house_override_result: 1
  index house_override_result_at: 1
  index senate_override_result: 1
  index senate_override_result_at: 1
  index awaiting_signature: 1
  index awaiting_signature_since: 1
  index vetoed: 1
  index vetoed_at: 1
  index enacted: 1
  index enacted_at: 1

  index last_version_on: 1
  index abbreviated: 1

  index updated_at: 1

  # spell out YYYY-MM-DD fields as strings
  field :last_version_on


  # citations
  cite_key :bill_id
  index citation_ids: 1
end