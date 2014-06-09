class CongressionalDocument
  include Api::Model
  # just using elasticsearch
  publicly :searchable

  basic_fields :document_id, :document_type_name, :chamber,
            :committee_id, :congress, :house_event_id,
            :hearing_title, :bill_id, :description, 
            :version_code, :bioguide_id, :publish_date, :urls

  search_fields :committee_id, :congress, :house_event_id, :hearing_title, :bioguide_id, :publish_date

  cite_key :document_id

# add indexes

end