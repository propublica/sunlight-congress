class Bill
  include Api::Model
  publicly :queryable, :searchable
  
  basic_fields :document_type,
    # bill fields
    :bill_id, :bill_type, :number, :congress, :chamber, 
    :sponsor_id, :committee_ids, :related_bill_ids,
    :short_title, :official_title, :popular_title, :nicknames,
    :introduced_on, :history, :enacted_as,
    :last_action_at, :last_vote_at, :last_version_on, 
    :last_version, :urls, 
    :cosponsors_count, :withdrawn_cosponsors_count,
    # amendment fields
    :amendment_id, 
    :amends_bill_id, :amends_treaty_id, :amends_amendment_id,
    :offered_on, :proposed_on, :submitted_on,
    :sponsor_type, :sponsor_committee_id, :house_number,
    :description, :purpose, :title


  search_fields :popular_title, :official_title, :short_title, 
    :nicknames, :summary, :keywords, :text,
    # amendment fields
    :title, :purpose, :description 

  cite_key :bill_id

  
  
  include Mongoid::Document
  include Mongoid::Timestamps
  
  index document_type: 1
  index document_id: 1

  index bill_id: 1
  index({bill_type: 1, number: 1})

  # support an orderly ordering of recent bills
  index({introduced_on: 1, bill_type: 1, number: 1})

  index chamber: 1
  index congress: 1

  index keywords: 1
  index nicknames: 1
  
  index sponsor_id: 1
  index cosponsor_ids: 1
  index cosponsors_count: 1
  index withdrawn_cosponsor_ids: 1
  index withdrawn_cosponsors_count: 1
  index committee_ids: 1
  index related_bill_ids: 1
  index amendment_ids: 1

  index last_action_at: 1
  index "last_action.type" => 1
  index last_vote_at: 1
  index last_version_on: 1
  index summary_date: 1
    
  index introduced_on: 1
  index "history.active" => 1
  index "history.active_at" => 1
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
  index "enacted_as.congress" => 1
  index "enacted_as.law_type" => 1
  index "enacted_as.number" => 1

  index citation_ids: 1

  # for internal use in keeping upcoming field up to date
  index "upcoming.source" => 1

  # amendment-only fields
  index proposed_on: 1
  index offered_on: 1
  index submitted_on: 1
  index sponsor_type: 1
  index amendment_id: 1
  index amends_bill_id: 1
  index amends_amendment_id: 1
  index amends_treaty_id: 1
end