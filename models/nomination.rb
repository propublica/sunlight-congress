class Nomination
  include Api::Model

  publicly :queryable

  basic_fields :congress, :number, :nomination_id,
    :nominees, :organization, :committee_ids,
    :received_on, :last_action_at, :last_action

  search_fields :"nominees.name", :"nominees.position", :organization

  include Mongoid::Document
  include Mongoid::Timestamps

  field :number, type: String # can have hyphens in them

  index "nominees.position" => 1
  index nomination_id: 1
  index congress: 1
  index number: 1
  index received_on: 1
  index last_action_at: 1
  index "last_action.type" => 1
  index committee_ids: 1
end