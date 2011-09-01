class BillVersion
  include Searchable::Model
  
  result_fields :version_code, :bill, :bill_version_id
  searchable_fields :full_text, "bill.summary"
end