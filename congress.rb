#!/usr/bin/env ruby

require './config/environment'
require './api/sunlight'

include Api::Routes
helpers Api::Helpers

get queryable_route do
  check_key!

  model = params[:captures][0].singularize.camelize.constantize rescue nil
  format = format_for params
  fields = fields_for model, params
  filters = filters_for params
  order = order_for params, "_id"

  # allow a pagination exception for legislators and committees, by request
  if [Legislator, Committee].include?(model) and (params[:per_page] == "all")
    pagination = {page: nil, per_page: nil}
  else
    pagination = pagination_for params
  end

  query_string = query_string_for params

  conditions = Queryable.conditions_for model, query_string, filters, params

  if params[:explain] == 'true'
    results = Queryable.explain_for model, conditions, fields, order, pagination
  else
    criteria = Queryable.criteria_for model, conditions, fields, order, pagination
    documents = Queryable.documents_for model, criteria, fields
    documents = Citable.add_to model, documents, params
    results = Queryable.results_for criteria, documents, pagination
  end
  
  hit! "query", format

  if format == 'json'
    json results
  elsif format == 'xml'
    xml results
  end
end


get searchable_route do
  check_key!

  models = params[:captures][0].split(",").map {|m| m.singularize.camelize.constantize rescue nil}.compact
  format = format_for params
  fields = fields_for models, params
  pagination = pagination_for params
  filters = filters_for params
  order = order_for params, "_score"

  search_fields = Searchable.search_fields_for models

  # query is actually optional, these may both end up null
  query_string = query_string_for params
  query = Searchable.query_for query_string, params, search_fields

  filter = Searchable.filter_for filters
  other = Searchable.other_options_for params, search_fields
  
  begin
    if params[:explain] == 'true'
      results = Searchable.explain_for query_string, models, query, filter, fields, order, pagination, other
    else
      raw_results = Searchable.raw_results_for models, query, filter, fields, order, pagination, other
      documents = Searchable.documents_for query_string, fields, raw_results
      documents = Citable.add_to models, documents, params
      results = Searchable.results_for raw_results, documents, pagination
    end
  rescue ElasticSearch::RequestError => exc
    results = Searchable.error_from exc
  end
  
  hit! "search", format

  if format == 'json'
    json results
  elsif format == 'xml'
    xml results
  end
end


# special endpoints for doing lat/lng and zip-based lookups on legislators and districts
# uses mix of methods to return information, using helper methods in Location module

get(/(legislators|districts)\/locate\/?/) do
  check_key!

  error 500, "Provide a 'zip', or a 'latitude' and 'longitude'." unless params[:zip] or (params[:latitude] and params[:longitude])

  begin
    if params[:zip]
      if zip = Zip.where(zip: params[:zip]).first
        districts = zip['districts']
        location = {zip: params[:zip], districts: zip['districts']}
      else
        districts = []
      end
      
      details = {zip: params[:zip]}
    elsif params[:latitude] and params[:longitude]
      url = Location.url_for params[:latitude], params[:longitude]

      start = Time.now
      response = Location.response_for url
      elapsed = Time.now - start

      districts = Location.response_to_districts response

      location = {latitude: params[:latitude], longitude: params[:longitude], response: response, elapsed: elapsed, districts: districts}
    end
  rescue Location::LocationException => ex
    error 500, ex.message
  end

  if params[:captures][0] == "legislators"
    if districts.any?
      model = Legislator
      fields = fields_for model, params
      pagination = pagination_for params
      order = order_for params, "_id"
      conditions = Location.district_to_legislators districts
      
      if params[:explain] == 'true'
        explain = Queryable.explain_for model, conditions, fields, order, pagination
        results = {location: location, query: explain}
      else
        criteria = Queryable.criteria_for model, conditions, fields, order, pagination
        documents = Queryable.documents_for model, criteria, fields
        results = Queryable.results_for criteria, documents, pagination
      end
    else # districts
      if params[:explain]
        results = {location: location}
      else
        results = {results: [], count: 0}
      end
    end

  else # districts
    if params[:explain]
      results = {location: location, districts: districts}
    else
      results = {results: districts, count: districts.size}
    end
  end

  hit! "locate", "json"

  json results
end


helpers do

  def json(results)
    response['Content-Type'] = 'application/json'
    json = Oj.dump results, mode: :compat, time_format: :ruby
    if params[:callback].present? and params[:callback] =~ /^[a-zA-Z0-9\$_]+$/
      "#{params[:callback]}(#{json});"
    else
      json
    end
  end
  
  def xml(results)
    response['Content-Type'] = 'application/xml'
    results.to_xml root: 'results', dasherize: false
  end

  def error(status, message)
    format = format_for params

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

  def check_key!
    if Environment.check_key? and !ApiKey.allowed?(api_key)
      error 403, 'API key required, you can obtain one from http://services.sunlightlabs.com/accounts/register/'
    end
  end

  def api_key
    params[:apikey] || request.env['HTTP_X_APIKEY']
  end

  def hit!(method_type, format)
    return if params[:explain]

    method = params[:captures][0]
    key = api_key || "debug"
    now = Time.zone.now

    extras = {}

    if method_type == "locate"
      if params[:zip]
        method += ".zip"
        extras[:zip] = params[:zip]
      elsif params[:latitude] and params[:longitude]
        method += ".latlng"
        extras[:latitude] = params[:latitude]
        extras[:longitude] = params[:longitude]
      end
    elsif method_type == "search"
      method += ".search"
      extras[:query] = params[:query]
    end

    hit = Hit.create!(
      key: key,
      
      method: method,
      method_type: method_type,
      format: format,

      extras: extras,
      
      user_agent: request.env['HTTP_USER_AGENT'],
      app_version: request.env['HTTP_X_APP_VERSION'],
      os_version: request.env['HTTP_X_OS_VERSION'],
      app_channel: request.env['HTTP_X_APP_CHANNEL'],

      created_at: now.utc,
      elapsed: ((now - request.env['timer']) * 1000000).to_i
    )

    HitReport.log! now.strftime("%Y-%m-%d"), key, method
  end

end

before {request.env['timer'] = Time.now}