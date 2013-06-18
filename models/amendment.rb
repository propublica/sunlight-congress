# Many fields similar to Bill, but also a lot of different assumptions.

class Amendment
  include Api::Model
  publicly :queryable, :searchable

  basic_fields :amendment_id,
    :amendment_type, :congress, :chamber,
    :number, :house_number, :offered_order,
    :last_action_at,
    :amends_bill_id, :amends_treaty_id, :amends_amendment_id,
    :introduced_on, :proposed_on,
    :sponsor_type, :sponsor_id,
    :purpose, :description

  search_fields :purpose, :description


  include Mongoid::Document
  include Mongoid::Timestamps

  index number: 1
  index congress: 1
  index amendment_type: 1
  index chamber: 1
  index last_action_at: 1

  index introduced_on: 1
  index proposed_on: 1

  index sponsor_id: 1
  index sponsor_type: 1
  index amendment_id: 1
  index amends_bill_id: 1
  index amends_amendment_id: 1
  index amends_treaty_id: 1
end