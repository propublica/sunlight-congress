class Vote
  include Api::Model
  publicly :queryable
  
  search_fields :question

  basic_fields :roll_id, :number, :year, :chamber, :congress, 
    :question, :result, :voted_at, :required,
    :roll_type, :vote_type, 
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
  index required: 1

  # common breakdown filters
  ["Yea", "Nay", "Not Voting", "Present", "Guilty", "Not Guilty"].each do |vote|
    index "breakdown.total.#{vote}" => 1
    index "breakdown.party.D.#{vote}" => 1
    index "breakdown.party.R.#{vote}" => 1
    index "breakdown.party.I.#{vote}" => 1
  end
end