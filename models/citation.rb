class Citation
  include Mongoid::Document
  include Mongoid::Timestamps

  # private mongodb collection - not accessible directly through frontend
  # used as a store for citation information, especially excerpts

  field :document_id # e.g. the bill_id value
  field :document_type # e.g. "bill"

  field :citation_id # e.g. 5_usc_552
  field :citation_type # e.g. "usc"

  # citations direct from citation.js, indexed by citation ID (e.g. usc.id)
  field :citations, type: Array

  # index [[:document_id, Mongo::ASCENDING], [:document_type, Mongo::ASCENDING]]
  index [[:document_id, Mongo::ASCENDING], [:citation_id, Mongo::ASCENDING]]
end