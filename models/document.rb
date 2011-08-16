class Document

  include Queryable::Model

  default_order :posted_at

  basic_fields :posted_at, :document_type, :url


  include Mongoid::Document
  include Mongoid::Timestamps

  index :posted_at
  index :document_type


  # document-specific fields

  # whip_notice
  index :notice_type
  index :party
  index :chamber
  index :for_date

  # crs_report
  index :order_code

  # cbo_estimate
  index :estimate_id
end
