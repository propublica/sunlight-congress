class Document

  include Queryable::Model

  default_order :posted_at

  basic_fields :posted_at, :document_type, :url, :title, :party, :order_code, :for_date, 
    :chamber, :notice_type, :estimate_id, :categories, :gao_id
  search_fields :title, # all
    :description, :categories # cbo_estimate


  include Mongoid::Document
  include Mongoid::Timestamps

  index posted_at: 1
  index document_type: 1


  # document-specific fields

  # whip_notice
  index notice_type: 1
  index party: 1
  index chamber: 1
  index for_date: 1

  # crs_report
  index order_code: 1

  # cbo_estimate
  index estimate_id: 1
  index categories: 1

  # gao_report
  index gao_id: 1
end
