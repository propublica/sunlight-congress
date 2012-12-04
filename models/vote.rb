class Vote
  include Api::Model
  publicly :queryable, :searchable
  
  search_fields :question, 
    "bill.text", "bill.summary", "bill.keywords", 
    "bill.official_title", "bill.popular_title", "bill.short_title"

  basic_fields :roll_id, :number, :year, :chamber, :congress, 
    :question, :result, :voted_at, :required,
    :roll_type, :vote_type, :passage_type, 
    :bill_id, :amendment_id
  
  

  # MongoDB behavior

  include Mongoid::Document
  include Mongoid::Timestamps
  
  index roll_id: 1
  index chamber: 1
  index year: 1
  index congress: 1
  
  index bill_id: 1
  index amendment_id: 1

  index result: 1
  index voted_at: 1

  index roll_type: 1
  index vote_type: 1
  index passage_type: 1
end