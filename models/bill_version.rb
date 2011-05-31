class BillVersion
  include Searchable::Model
  
  result_fields :version_code, :bill
  searchable_fields :full_text
end