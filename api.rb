#!/usr/bin/env ruby

require 'environment'
configure(:development) {require 'sinatra/reloader'}


get /^\/(#{models.join "|"})\.(json)$/ do
  model = params[:captures][0].camelize.constantize rescue raise(Sinatra::NotFound)
  
  conditions = conditions_for model.unique_keys, params
  fields = fields_for model, params[:sections]
  
  unless conditions.any? and document = model.where(conditions).only(fields).first
    raise Sinatra::NotFound
  end
  
  json model, attributes_for(document)
end

get /^\/(#{models.map(&:pluralize).join "|"})\.(json)$/ do
  model = params[:captures][0].singularize.camelize.constantize rescue raise(Sinatra::NotFound)
  
  fields = fields_for model, params[:sections]
  conditions = search_conditions_for model, params
  order = order_for model, params
  
  bills = model.where(conditions).only(fields).order_by(order).all.paginate(pagination_for(params))
  
  #TODO: Pagination
  
  json model, attributes_for(bills)
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
  
  def search_conditions_for(model, params)
    conditions = {}
    model.search_keys.keys.each do |key|
      if params[key]
        if model.search_keys[key] == Boolean
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
    
    [[key, sort], [model.unique_keys.first, :desc]]
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
    if document.is_a? Array
      document.map {|d| attributes_for d}
    else
      attributes = document.attributes
      attributes.delete :_id
      attributes
    end
  end
  
  def json(model, object)
    response['Content-Type'] = 'application/json'
    
    key = model.to_s.underscore
    key = key.pluralize if object.is_a?(Array)
    
    json = {key => object}.to_json
    
    params[:callback].present? ? "#{params[:callback]}(#{json});" : json
  end
  
end