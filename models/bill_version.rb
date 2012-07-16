class BillVersion
  include Searchable::Model
  
  result_fields :version_code, :bill, :bill_version_id, :version_name, :issued_on, :urls
  searchable_fields :full_text, "bill.summary", "bill.keywords", "bill.official_title", "bill.popular_title", "bill.short_title"

  
  # stored internally in MongoDB, not exposed
  include Mongoid::Document
  include Mongoid::Timestamps

  index "bill.bill_id"
  index "usc.extracted_ids"
  index :bill_version_id
  index :issued_on
  index :version_code
end