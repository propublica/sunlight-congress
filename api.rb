#!/usr/bin/env ruby

require 'config/environment'

# reload in development without starting server
configure(:development) do |config|
  require 'sinatra/reloader'
  config.also_reload "config/environment.rb"
  config.also_reload "analytics/*.rb"
  config.also_reload "models/*.rb"
end


set :logging, false

require 'analytics/api_key'
require 'analytics/hits'


# load all models and prepare them to be API-ized
models = []
Dir.glob('models/*.rb').each do |filename|
  model_name = File.basename filename, File.extname(filename)
  model = model_name.camelize.constantize
  models << model_name unless model.respond_to?(:api?) and !model.api?
end


get /^\/(#{models.map(&:pluralize).join "|"})\.(json|xml)$/ do
  model = params[:captures][0].singularize.camelize.constantize
  format = params[:captures][1]
  
  fields = fields_for model, params
  conditions = filter_conditions_for model, params
  order = order_for model, params
  
  criteria = model.where(conditions).only(fields).order_by(order)
  
  results = results_for model, criteria, conditions
  
  if format == 'json'
    json results
  elsif format == 'xml'
    xml results
  end
end


helpers do
  
  def fields_for(model, params)
    return nil if params[:sections].blank?
    
    sections = params[:sections].split ','
    
    if sections.include?('basic')
      sections.delete 'basic' # does nothing if not present
      sections += model.basic_fields.map {|field| field.to_s}
    end
    sections.uniq
  end
  
  def filter_conditions_for(model, params)
    conditions = {}
    
    params.each do |key, value|
      
      # if there's a special operator (>, <, !, __ne, etc.), strip it off the key
      operators = {
        ">" => :gte, 
        "<" => :lte, 
        "!" => :ne,
        "__gt" => :gt, 
        "__lt" => :lt,
        "__gte" => :gte,
        "__lte" => :lte, 
        "__ne" => :ne,
        "__match" => :match,
        "__match_i" => :match_i,
        "__exists" => :exists,
        "__in" => :in,
        "__nin" => :nin
      }
      
      operator = nil
      if key =~ /^(.*?)(#{operators.keys.join "|"})$/
        key = $1
        operator = operators[$2]
      end
      
      if !magic_fields.include? key.to_sym
        
        # transform 'value' to the correct type for this key if needed
        if [:nin, :in].include?(operator)
          value = value.split("|").map {|v| value_for v, model.fields[key]}
        else
          value = value_for value, model.fields[key]
        end
        
#         puts
#         puts "value: #{value.inspect} (#{value.class})"
        
        if operator
          if conditions[key].nil? or conditions[key].is_a?(Hash)
            # error point: invalid regexp, check now
            conditions[key] ||= {}
            
            if [:lt, :lte, :gt, :gte, :ne, :in, :nin, :exists].include?(operator)
              conditions[key]["$#{operator}"] = value 
            elsif operator == :match
              conditions[key] = /#{value}/ rescue nil # avoid RegexpError
            elsif operator == :match_i
              conditions[key] = /#{value}/i rescue nil # avoid RegexpError
            end
          else
            # let it fall, someone already assigned the filter directly
            # this is for edge cases like x>=2&x=1, where x=1 should take precedence
          end
        else
          # override anything that may already be there
          conditions[key] = value
        end
        
      end
    end
    
#     puts
#     puts "conditions: #{conditions.inspect}"
#     puts

    conditions
  end
  
  
  def value_for(value, field)
    # type overridden in model
    if field
      if field.type == Boolean
        (value == "true") if ["true", "false"].include? value
      elsif field.type == Integer
        value.to_i
      elsif [Date, Time, DateTime].include?(field.type)
        Time.parse value
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
        Time.parse value
      else
        value
      end
    end
  end
  
  def order_for(model, params)
    key = nil
    if params[:order].present?
      key = params[:order].to_sym
    else
      key = model.default_order
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

  def attributes_for(document)
    attributes = document.attributes
    [:_id, :created_at, :updated_at].each {|key| attributes.delete key}
    attributes
  end
  
  def results_for(model, criteria, conditions)
    key = model.to_s.underscore.pluralize
    pagination = pagination_for params
    
    # documents is a Mongoid::Criteria, so it hasn't been lazily executed yet
    # #count will not trigger it, #paginate will
    total_count = criteria.count
    documents = criteria.paginate pagination
    
    {
      key => documents.map {|document| attributes_for document},
      :count => total_count,
      :page => {
        :count => documents.size,
        :per_page => pagination[:per_page],
        :page => pagination[:page]
      },
      :conditions => conditions
    }
  end
  
  def json(results)
    response['Content-Type'] = 'application/json'    
    json = results.to_json
    params[:callback].present? ? "#{params[:callback]}(#{json});" : json
  end
  
  def xml(results)
    response['Content-Type'] = 'application/xml'
    results.delete :conditions # operators with $'s are invalid XML
    results.to_xml :root => 'results'
  end
  
end