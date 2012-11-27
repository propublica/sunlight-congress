class Committee
  include Mongoid::Document
  include Mongoid::Timestamps
  
  index({committee_id: 1}, {unique: true})
  index chamber: 1
  index subcommittee: 1
  index membership_ids: 1
  index congresses: 1
  
  validates_presence_of :committee_id
  validates_presence_of :chamber
  validates_presence_of :subcommittee
  validates_presence_of :name


  include ::Queryable::Model

  default_order :created_at
  basic_fields :committee_id, :name, :chamber, :subcommittee,
    :website, :address, :office, :phone,
    :senate_committee_id, :house_committee_id
  search_fields :name
end