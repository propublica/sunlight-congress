class Bill
  include Api::Model
  publicly :queryable, :searchable
  
  basic_fields :bill_id, :bill_type, :number, :congress, :chamber, 
    :sponsor_id, :committee_ids, :related_bill_ids,
    :short_title, :official_title, :popular_title, :nicknames,
    :introduced_at, :history, :enacted_as,
    :last_action_at, :last_vote_at, :last_version_on

  search_fields :popular_title, :official_title, :short_title, 
    :nicknames, :summary, :keywords, :text

  cite_key :bill_id

  
  
  include Mongoid::Document
  include Mongoid::Timestamps
  
  index bill_id: 1
  index({bill_type: 1, number: 1})
  index chamber: 1
  index congress: 1

  index keywords: 1
  index nicknames: 1
  
  index sponsor_id: 1
  index cosponsor_ids: 1
  index withdrawn_cosponsor_ids: 1
  index committee_ids: 1
  index related_bill_ids: 1
  index amendment_ids: 1

  index last_action_at: 1
  index last_vote_at: 1
  index last_version_on: 1
    
  index introduced_at: 1
  index "history.house_passage_result" => 1
  index "history.house_passage_result_at" => 1
  index "history.senate_passage_result" => 1
  index "history.senate_passage_result_at" => 1
  index "history.house_override_result" => 1
  index "history.house_override_result_at" => 1
  index "history.senate_override_result" => 1
  index "history.senate_override_result_at" => 1
  index "history.awaiting_signature" => 1
  index "history.awaiting_signature_since" => 1
  index "history.vetoed" => 1
  index "history.vetoed_at" => 1
  index "history.enacted" => 1
  index "history.enacted_at" => 1
  index enacted_as: 1

  index citation_ids: 1
end