#!/usr/bin/env ruby

require 'config/environment'

# reload in development without starting server
configure(:development) do |config|
  require 'sinatra/reloader'
  config.also_reload "analytics/*.rb"
  config.also_reload "models/*.rb"
end


set :logging, false

require 'analytics/api_key'
require 'analytics/hits'


# load all models and prepare them to be API-ized

models = {:singular => [], :plural => []}

Dir.glob('models/*.rb').each do |filename|
  model_name = File.basename filename, File.extname(filename)
  model = model_name.camelize.constantize
  unless model.respond_to?(:api?) and !model.api?
    models[:singular] << model_name unless model.respond_to?(:singular_api?) and !model.singular_api?
    models[:plural] << model_name unless model.respond_to?(:plural_api?) and !model.plural_api?
  end
end


# generalized singular and plural methods

get /^\/(#{models[:singular].join "|"})\.(json|xml)$/ do
  model = params[:captures][0].camelize.constantize rescue raise(Sinatra::NotFound)
  
  fields = fields_for model, params[:sections]
  conditions = unique_conditions_for model, params
  
  unless conditions.any? and document = model.where(conditions).only(fields).first
    raise Sinatra::NotFound
  end
  
  output_for params[:captures][1], model, documents
end

get /^\/(#{models[:plural].map(&:pluralize).join "|"})\.(json|xml)$/ do
  model = params[:captures][0].singularize.camelize.constantize rescue raise(Sinatra::NotFound)
  
  fields = fields_for model, params[:sections]
  conditions = filter_conditions_for model, params
  order = order_for model, params
  
  documents = model.where(conditions).only(fields).order_by(order).all
  
  output_for params[:captures][1], model, documents
end



# If this is a JSONP request, and it did trigger one of the main routes, return an error response
# Otherwise, let it lapse into a normal content-less 404
# If we don't do this, in-browser clients using JSONP have no way of detecting a problem
not_found do
  if params[:captures] and params[:captures][0] and params[:callback]
    json = {:error => {:code => 404, :message => "#{params[:captures][0].capitalize} not found"}}.to_json
    jsonp = "#{params[:callback]}(#{json});";
    halt 200, jsonp
  end
end


helpers do
  
  def fields_for(model, sections)
    return nil if sections.blank?
    
    sections = sections.split ','
    
    if sections.include?('basic')
      sections.delete 'basic' # does nothing if not present
      sections += model.basic_fields.map {|field| field.to_s}
    end
    sections.uniq
  end
  
  def unique_conditions_for(model, params)
    model.unique_keys.each do |key|
      return {key => params[key]} if params[key]
    end
    {}
  end
  
  def filter_conditions_for(model, params)
    conditions = {}
    model.filter_keys.keys.each do |key|
      if params[key]
        if model.filter_keys[key] == Boolean
          conditions[key] = (params[key] == "true") if ["true", "false"].include? params[key]
        else
          conditions[key] = params[key]
        end
      end
    end
    conditions
  end
  
  def order_for(model, params)
    key = nil
    if params[:order].present? and model.order_keys.include?(params[:order].to_sym)
      key = params[:order].to_sym
    else
      key = model.order_keys.first
    end
    
    sort = nil
    if params[:sort].present? and [:desc, :asc].include?(params[:sort].downcase.to_sym)
      sort = params[:sort].downcase.to_sym
    else
      sort = :desc
    end
    
    # meant to break ties in a predictable manner
    total_sort = [[key, sort]]
    if model.respond_to?(:unique_keys) and model.unique_keys.any? and model.unique_keys.first != key
      total_sort << [model.unique_keys.first, :desc]
    end
    
    total_sort
  end

  def pagination_for(params)
    default_per_page = 20
    max_per_page = 500
    max_page = 200000000 # let's keep it realistic
    
    # rein in per_page to somewhere between 1 and the max
    per_page = (params[:per_page] || default_per_page).to_i
    per_page = default_per_page if per_page <= 0
    per_page = max_per_page if per_page > max_per_page
    
    # valid page number, please
    page = (params[:page] || 1).to_i
    page = 1 if page <= 0 or page > max_page
    
    {:per_page => per_page, :page => page}
  end

  def attributes_for_single(document)
    attributes = document.attributes
    [:_id, :created_at, :updated_at].each {|key| attributes.delete key}
    attributes
  end
  
  def attributes_for_plural(model, documents)
    key = model.to_s.underscore.pluralize
    pagination = pagination_for params
    
    # documents is a Mongoid::Criteria, so it hasn't been lazily executed yet
    # counting will not trigger it, paginate will
    total_count = documents.count
    page = documents.paginate pagination
    
    {
      key => page.map {|document| attributes_for_single document},
      :count => total_count,
      :page => {
        :count => page.size,
        :per_page => pagination[:per_page],
        :page => pagination[:page]
      }
    }
  end
  
  def output_for(format, model, object)
    if format == 'json'
      json model, object
    elsif format == 'xml'
      xml model, object
    end
  end
  
  def json(model, object)
    response['Content-Type'] = 'application/json'    
    
    if object.is_a?(Mongoid::Criteria)
      json = attributes_for_plural(model, object).to_json
    else
      json = {model.to_s.underscore => attributes_for_single(object)}.to_json
    end
    
    params[:callback].present? ? "#{params[:callback]}(#{json});" : json
  end
  
  def xml(model, object)
    response['Content-Type'] = 'application/xml'
    
    if object.is_a?(Mongoid::Criteria)
      attributes_for_plural(model, object).to_xml :root => 'results'
    else
      attributes_for_single(object).to_xml :root => model.to_s.underscore
    end
  end
  
end