class CongressionalDocument 
  include Api::Model
  # just using elasticsearch
  publicly :searchable

  basic_fields :id, :document_type_name, :chamber,
            :committee_id, :congress, :house_event_id,
            :hearing_title, :bill_id, :description, 
            :version_code, :bioguide_id, :published_on, :urls

  search_fields  :hearing_title, :text

  cite_key :document_id

# add indexes

end