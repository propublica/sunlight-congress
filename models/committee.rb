class Committee
  include Api::Model
  publicly :queryable

  basic_fields :committee_id, :name, :chamber, :subcommittee,
    :website, :address, :office, :phone,
    :senate_committee_id, :house_committee_id

  search_fields :name




  include Mongoid::Document
  include Mongoid::Timestamps
  
  index({committee_id: 1}, {unique: true})
  index chamber: 1
  index subcommittee: 1
  index membership_ids: 1
  index congresses: 1
end