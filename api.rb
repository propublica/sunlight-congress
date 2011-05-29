#!/usr/bin/env ruby

require 'config/environment'

require 'analytics/api_key'
require 'analytics/hits'

set :logging, false

configure(:development) do |config|
  require 'sinatra/reloader'
  config.also_reload "config/environment.rb"
  config.also_reload "analytics/*.rb"
  config.also_reload "models/*.rb"
  config.also_reload "queryable.rb"
end


get queryable_route do
  model = params[:captures][0].singularize.camelize.constantize
  format = params[:captures][1]

  fields = Queryable.fields_for model, params
  conditions = Queryable.filter_conditions_for model, params
  order = Queryable.order_for model, params
  pagination = Queryable.pagination_for params
  
  if params[:explain] == 'true'
    results = Queryable.explain_for model, conditions, fields, order, pagination
  else
    results = Queryable.results_for model, conditions, fields, order, pagination
  end
  
  if format == 'json'
    json results
  elsif format == 'xml'
    xml results
  end
end


helpers do
  
  def json(results)
    response['Content-Type'] = 'application/json'
    json = results.to_json
    params[:callback].present? ? "#{params[:callback]}(#{json});" : json
  end
  
  def xml(results)
    response['Content-Type'] = 'application/xml'
    results.to_xml :root => 'results', :dasherize => false
  end
  
end