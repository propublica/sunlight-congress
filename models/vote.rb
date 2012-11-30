class Vote
  include Api::Model
  publicly :queryable, :searchable
  
  search_fields :question, 
    "bill.last_version_text", "bill.summary", "bill.keywords", 
    "bill.official_title", "bill.popular_title", "bill.short_title", 
    "amendment.purpose"

  basic_fields :how, :roll_id, :number, :year, :chamber, :congress, 
    :result, :bill_id, :voted_at, :last_updated, :roll_type, :question, 
    :required, :vote_type, :passage_type, :amendment_id, :vote_breakdown
  
  

  # MongoDB behavior

  include Mongoid::Document
  include Mongoid::Timestamps
  
  index roll_id: 1
  index chamber: 1
  index congress: 1
  index type: 1
  index result: 1
  index voted_at: 1
  index roll_type: 1
  index vote_type: 1
  index passage_type: 1
  index required: 1
  index year: 1
  index number: 1
  index how: 1
  index bill_id: 1
  index amendment_id: 1
end