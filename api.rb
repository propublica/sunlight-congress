#!/usr/bin/env ruby

require 'environment'
configure(:development) {require 'sinatra/reloader'}



get /^\/([^\.]+)\.(json)$/ do
  model = params[:captures][0].camelize.constantize rescue raise(Sinatra::NotFound)
  
  conditions = conditions_for model.unique_keys, params
  fields = fields_for model, params[:sections]
  
  unless conditions.any? and document = model.where(conditions).only(fields).first
    raise Sinatra::NotFound
  end
  
  json model, attributes_for(document)
end

# get /^\/api\/(bills)\.(json)$/ do
#   fields = fields_for Bill, params[:sections]
#   conditions = search_conditions_for Bill, params
#   order = order_for Bill, params
#   
#   bills = Bill.all({
#     :conditions => conditions,
#     :fields => fields,
#     :order => order,
#   }.merge(pagination_for(params)))
#   
#   json Bill, bills.map {|bill| attributes_for bill, fields}, params[:callback]
# end

not_found do
  # If this is a JSONP request, and it did trigger one of the main routes, return an error response
  # Otherwise, let it lapse into a normal content-less 404
  
  # If we don't do this, in-browser clients using JSONP have no way of detecting a problem
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
    order_key = model.order_keys.detect {|key| params[:order].present? and params[:order].to_sym == key} || model.order_keys.first
    order_sort = ['DESC', 'ASC'].detect {|sort| params[:sort].to_s.upcase == sort} || 'DESC'
    
    secondary_sort = "#{model.unique_keys.first} DESC"
    
    "#{order_key} #{order_sort}, #{secondary_sort}"
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
    
    {:limit => per_page, :offset => (page - 1 ) * per_page}
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