class Nomination
  include Api::Model

  publicly :queryable

  basic_fields :congress, :number, :nomination_id,
    :name, :nominee, :organization, :state, :position,
    :received_on, :last_action_at

  search_fields :name, :nominee, :organization, :position

  include Mongoid::Document
  include Mongoid::Timestamps

  field :number, type: String

  index nomination_id: 1
  index congress: 1
  index number: 1
  index state: 1
  index received_on: 1
  index last_action_at: 1
end