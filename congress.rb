#!/usr/bin/env ruby

require './config/environment'
require './analytics/api_key'
require './analytics/hits'

disable :protection
disable :logging


get Api.queryable_route do
  model = params[:captures][0].singularize.camelize.constantize rescue nil
  error 400, "Bad method" unless model

  format = Api.format_for params
  fields = Api.fields_for model, params
  pagination = Api.pagination_for params

  conditions = Api::Queryable.conditions_for model, params
  order = Api::Queryable.order_for model, params

  if params[:explain] == 'true'
    results = Api::Queryable.explain_for model, conditions, fields, order, pagination
  else
    criteria = Api::Queryable.criteria_for model, conditions, fields, order, pagination
    documents = Api::Queryable.documents_for model, criteria, fields
    documents = citations_for model, documents, params
    results = Api::Queryable.results_for criteria, documents, pagination
  end
  
  if format == 'json'
    json results
  elsif format == 'xml'
    xml results
  end
end


get Api.searchable_route do
  models = params[:captures][0].split(",").map {|m| m.singularize.camelize.constantize rescue nil}.compact
  error 400, "Bad method" unless models.any?
  
  format = Api.format_for params
  fields = Api.fields_for models, params
  pagination = Api.pagination_for params

  search_fields = Api::Searchable.search_fields_for models

  # query is actually optional, these may both end up null
  query_string = Api::Searchable.query_string_for params
  query = Api::Searchable.query_for query_string, params, search_fields

  filter = Api::Searchable.filter_for models, params
  order = Api::Searchable.order_for params
  other = Api::Searchable.other_options_for params, search_fields
  
  begin
    if params[:explain] == 'true'
      results = Api::Searchable.explain_for query_string, models, query, filter, fields, order, pagination, other
    else
      raw_results = Api::Searchable.raw_results_for models, query, filter, fields, order, pagination, other
      documents = Api::Searchable.documents_for query_string, fields, raw_results
      documents = citations_for models, documents, params
      results = Api::Searchable.results_for raw_results, documents, pagination
    end
  rescue ElasticSearch::RequestError => exc
    results = Api::Searchable.error_from exc
  end
  
  if format == 'json'
    json results
  elsif format == 'xml'
    xml results
  end
end


helpers do

  def citations_for(models, documents, params)
    models = [models] unless models.is_a?(Array)

    # must explicitly ask for extra information and performance hit
    return documents unless params[:citation_details].present?

    # only citation-enabled models
    return documents unless params[:citation].present? and models.select {|model| model.cite_key.nil?}.empty?

    criteria = {}

    citation_ids = params[:citation].split "|"
    if citation_ids.size > 1
      criteria.merge! citation_id: {"$in" => citation_ids}
    else
      criteria.merge! citation_id: citation_ids.first
    end

    if models.size > 1
      criteria.merge! document_type: {"$in" => models.map(&:to_s)}
    else
      criteria.merge! document_type: models.first.to_s
    end

    documents.map do |document|
      if models.size > 1
        model = document[:search][:type].camelize.constantize
      else
        model = models.first
      end

      matches = Citation.where(
        criteria.merge(
          document_id: document[model.cite_key.to_s]
        )
      )
      
      if matches.any?
        citations = []
        matches.each do |match|
          citations += match['citations']
        end
        document['citations'] = citations
      end

      document
    end
  end

  def error(status, message)
    format = Api.format_for params

    results = {
      error: message,
      status: status
    }

    if format == "json"
      halt 200, json(results)
    else
      halt 200, xml(results)
    end
  end
  
  def json(results)
    response['Content-Type'] = 'application/json'
    json = Oj.dump results, mode: :compat, time_format: :ruby
    params[:callback].present? ? "#{params[:callback]}(#{json});" : json
  end
  
  def xml(results)
    response['Content-Type'] = 'application/xml'
    results.to_xml :root => 'results', :dasherize => false
  end

end