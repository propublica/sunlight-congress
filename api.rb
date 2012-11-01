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

# backwards compatibility - 'sections' will still work
before do
  if params[:sections].present?
    params[:fields] = params[:sections]
  elsif params[:fields].present?
    params[:sections] = params[:fields]
  end
end

get queryable_route do
  model = params[:captures][0].singularize.camelize.constantize
  format = params[:captures][1]

  fields = Queryable.fields_for model, params
  conditions = Queryable.conditions_for model, params
  order = Queryable.order_for model, params
  pagination = Queryable.pagination_for params

  if params[:explain] == 'true'
    results = Queryable.explain_for model, conditions, fields, order, pagination
  else
    criteria = Queryable.criteria_for model, conditions, fields, order, pagination
    documents = Queryable.documents_for model, criteria, fields
    documents = citations_for model, documents, params
    results = Queryable.results_for model, criteria, documents, pagination
  end
  
  if format == 'json'
    json results
  elsif format == 'xml'
    xml results
  end
end


get searchable_route do
  error 400, "You must provide a search term with the 'query' parameter (for phrase searches) or 'q' parameter (for query string searches)." unless params[:query] or params[:q]

  models = params[:captures][0].split(",").map {|m| m.singularize.camelize.constantize}
  format = params[:captures][1]

  term = Searchable.term_for params
  fields = Searchable.fields_for models, params
  search_fields = Searchable.search_fields_for models, params

  if search_fields.empty?
    error 400, "You must search one of the following fields for #{params[:captures][0]}: #{model.searchable_fields.join(", ")}"
  end
  
  if params[:query]
    query = Searchable.query_for term, params, search_fields
  elsif params[:q]
    query = Searchable.relaxed_query_for term, params, search_fields
  end

  filter = Searchable.filter_for models, params
  order = Searchable.order_for params
  pagination = Searchable.pagination_for params
  other = Searchable.other_options_for params, search_fields
  
  begin
    if params[:explain] == 'true'
      results = Searchable.explain_for term, models, query, filter, fields, order, pagination, other
    else
      raw_results = Searchable.raw_results_for term, models, query, filter, fields, order, pagination, other
      documents = Searchable.documents_for term, fields, raw_results
      documents = citations_for models, documents, params
      results = Searchable.results_for term, models, raw_results, documents, pagination
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
    format = params[:captures][1]

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
    xml_exceptions results
    response['Content-Type'] = 'application/xml'
    results.to_xml :root => 'results', :dasherize => false
  end
  
  # a hard-coded XML exception for vote names, which I foolishly made as keys
  # this will be fixed in v2
  def xml_exceptions(results)
    if results['votes']
      results['votes'].each do |vote|
        if vote['vote_breakdown']
          vote['vote_breakdown'] = dasherize_hash vote['vote_breakdown']
        end
      end
    end
  end
  
  def dasherize_hash(original)
    hash = original.dup
    
    hash.keys.each do |key|
      value = hash.delete key
      key = key.tr(' ', '-')
      if value.is_a?(Hash)
        hash[key] = dasherize_hash(value)
      else
        hash[key] = value
      end
    end
    
    hash
  end
  
end