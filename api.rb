#!/usr/bin/env ruby

require './config/environment'

require './analytics/api_key'
require './analytics/hits'

set :logging, false

configure(:development) do |config|
  require 'sinatra/reloader'
  config.also_reload "./config/environment.rb"
  config.also_reload "./analytics/*.rb"
  config.also_reload "./models/*.rb"
  config.also_reload "./queryable.rb"
  config.also_reload "./searchable.rb"
end

# disable XSS check, this is an API and it's okay to use it with JSONP
disable :protection


get queryable_route do
  model = params[:captures][0].singularize.camelize.constantize
  format = params[:format] || "json"

  fields = Queryable.fields_for model, params
  conditions = Queryable.conditions_for model, params
  order = Queryable.order_for model, params
  pagination = Api.pagination_for params

  if params[:explain] == 'true'
    results = Queryable.explain_for model, conditions, fields, order, pagination
  else
    criteria = Queryable.criteria_for model, conditions, fields, order, pagination
    documents = Queryable.documents_for model, criteria, fields
    documents = citations_for model, documents, params
    results = Queryable.results_for criteria, documents, pagination
  end
  
  if format == 'json'
    json results
  elsif format == 'xml'
    xml results
  end
end


get searchable_route do
  error 400, "You must provide a query string with the 'query' parameter (for phrase searches) or 'q' parameter (for query string searches)." unless params[:query]

  models = params[:captures][0].split(",").map {|m| m.singularize.camelize.constantize}
  format = params[:format] || "json"

  query_string = Searchable.query_string_for params
  fields = Searchable.fields_for models, params
  search_fields = Searchable.search_fields_for models, params

  if search_fields.empty?
    error 400, "You must search one of the following fields for #{params[:captures][0]}: #{model.searchable_fields.join(", ")}"
  end
  
  if params[:query]
    query = Searchable.query_for query_string, params, search_fields
  end

  filter = Searchable.filter_for models, params
  order = Searchable.order_for params
  other = Searchable.other_options_for params, search_fields
  pagination = Api.pagination_for params
  
  begin
    if params[:explain] == 'true'
      results = Searchable.explain_for query_string, models, query, filter, fields, order, pagination, other
    else
      raw_results = Searchable.raw_results_for models, query, filter, fields, order, pagination, other
      documents = Searchable.documents_for query_string, fields, raw_results
      documents = citations_for models, documents, params
      results = Searchable.results_for raw_results, documents, pagination
    end
  rescue ElasticSearch::RequestError => exc
    results = Searchable.error_from exc
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
    format = params[:format] || "json"

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


class Api
  def self.pagination_for(params)
    default_per_page = 20
    max_per_page = 50
    max_page = 200000000 # let's keep it realistic
    
    # rein in per_page to somewhere between 1 and the max
    per_page = (params[:per_page] || default_per_page).to_i
    per_page = default_per_page if per_page <= 0
    per_page = max_per_page if per_page > max_per_page
    
    # valid page number, please
    page = (params[:page] || 1).to_i
    page = 1 if page <= 0 or page > max_page
    
    {per_page: per_page, page: page}
  end

  def self.value_for(value, field)
    # type overridden in model
    if field
      if field.type == Boolean
        (value == "true") if ["true", "false"].include? value
      elsif field.type == Integer
        value.to_i
      elsif [Date, Time, DateTime].include?(field.type)
        Time.zone.parse(value).utc rescue nil
      else
        value
      end
      
    # try to autodetect type
    else
      if ["true", "false"].include? value # boolean
        value == "true"
      elsif value =~ /^\d+$/
        value.to_i
      elsif (value =~ /^\d\d\d\d-\d\d-\d\d$/) or (value =~ /^\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d/)
        Time.zone.parse(value).utc rescue nil
      else
        value
      end
    end
  end
end