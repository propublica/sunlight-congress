class Document

  include Queryable::Model

  default_order :posted_at

  basic_fields :document_id, :posted_at, :document_type, :document_type_name, # all
    :title, :source_url, :url, # all

    :party, :chamber, :notice_type, :for_date, # whip_notice
    :order_code, # crs_report
    :description, :estimate_id, # cbo_estimate 
    :gao_id, # gao_report
    :categories # cbo_estimate, gao_reports

  search_fields :title, # all
    :description, # cbo_estimate
    :categories # cbo_estimate, gao_reports


  include Searchable::Model

  result_fields *(self.basic_fields)
  searchable_fields *(self.search_fields + [:text])


  include Mongoid::Document
  include Mongoid::Timestamps

  index document_id: 1
  index posted_at: 1
  index document_type: 1

  index notice_type: 1
  index party: 1
  index chamber: 1
  index for_date: 1
  index order_code: 1

  index estimate_id: 1
  index categories: 1

  index gao_id: 1
end
