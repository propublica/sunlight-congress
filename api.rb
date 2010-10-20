#!/usr/bin/env ruby

require 'config/environment'
configure(:development) {require 'sinatra/reloader'}

def models
  @models ||= load_models
end

set :logging, false

def load_models
  all_models = {:singular => [], :plural => []}
  
  Dir.glob('models/*.rb').each do |filename|
    model_name = File.basename filename, File.extname(filename)
    model = model_name.camelize.constantize
    unless model.respond_to?(:api?) and !model.api?
      all_models[:singular] << model_name unless model.respond_to?(:singular_api?) and !model.singular_api?
      all_models[:plural] << model_name unless model.respond_to?(:plural_api?) and !model.plural_api?
    end
  end
  
  all_models
end

get /^\/(#{models[:singular].join "|"})\.(json)$/ do
  model = params[:captures][0].camelize.constantize rescue raise(Sinatra::NotFound)
  
  conditions = conditions_for model.unique_keys, params
  fields = fields_for model, params[:sections]
  
  unless conditions.any? and document = model.where(conditions).only(fields).first
    raise Sinatra::NotFound
  end
  
  json model, document
end

get /^\/(#{models[:plural].map(&:pluralize).join "|"})\.(json)$/ do
  model = params[:captures][0].singularize.camelize.constantize rescue raise(Sinatra::NotFound)
  
  fields = fields_for model, params[:sections]
  conditions = filter_conditions_for model, params
  order = order_for model, params
  
  documents = model.where(conditions).only(fields).order_by(order).all
  
  json model, documents
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
  
  def conditions_for(keys, params)
    conditions = {}
    keys.each do |key|
      conditions[key] = params[key] if params[key]
    end
    conditions
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

  def attributes_for(document)
    attributes = document.attributes
    [:_id, :created_at, :updated_at].each {|key| attributes.delete key}
    attributes
  end
  
  def json(model, object)
    response['Content-Type'] = 'application/json'
    
    if object.is_a?(Mongoid::Criteria)
      documents = object
      
      key = model.to_s.underscore.pluralize
      total_count = documents.count
      pagination = pagination_for params
      
      page = documents.paginate pagination
      
      json = {
        key => page.map {|document| attributes_for document},
        :count => total_count,
        :page => {
          :count => page.size,
          :per_page => pagination[:per_page],
          :page => pagination[:page]
        }
      }.to_json
    else
      document = object
      
      key = model.to_s.underscore
      json = {key => attributes_for(document)}.to_json
    end
    
    params[:callback].present? ? "#{params[:callback]}(#{json});" : json
  end
  
end