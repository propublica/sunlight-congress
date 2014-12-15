class Document
  include Api::Model
  publicly :queryable, :searchable

  basic_fields :document_id, :document_type, :document_type_name,
    :posted_at, :published_on,
    :title, :categories,
    :source_url, :url

  search_fields :title, :categories, :text,
    "gao_report.description"

  cite_key :document_id
  default_order :published_on

  # experimental: RSS support
  rss title: "title",
      guid: "document_id",
      link: "url",
      pubDate: "published_on",
      # todo: it'd be nice to have a top-level description field
      description: "title"


  include Mongoid::Document
  include Mongoid::Timestamps

  validates_uniqueness_of :document_id
  validates_presence_of :posted_at
  validates_presence_of :url

  index document_id: 1
  index document_type: 1
  index posted_at: 1
  index categories: 1
  index citation_ids: 1
  index created_at: 1

  index "gao_report.gao_id" => 1
  index "ig_report.report_id" => 1
  index "ig_report.agency" => 1
  index "ig_report.year" => 1
  index "ig_report.type" => 1
  index "ig_report.audit_id" => 1
  index "ig_report.inspector" => 1
end