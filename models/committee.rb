class Committee
  include Api::Model
  publicly :queryable

  basic_fields :committee_id, :name, :chamber, 
    :subcommittee, :parent_committee_id,
    :website, :address, :office, :phone,
    :house_committee_id

  search_fields :name



  include Mongoid::Document
  include Mongoid::Timestamps
  
  index({committee_id: 1}, {unique: true})
  index chamber: 1
  index subcommittee: 1
  index parent_committee_id: 1
  index membership_ids: 1
end