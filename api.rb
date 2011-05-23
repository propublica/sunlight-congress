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
  
  if params[:explain] == 'true'
    results = explain_for criteria, conditions, fields, order
  else
    results = results_for model, criteria, conditions, fields
  end
  
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
        "__match_s" => :match_s,
        "__exists" => :exists,
        "__in" => :in,
        "__nin" => :nin,
        "__all" => :all
      }
      
      operator = nil
      if key =~ /^(.*?)(#{operators.keys.join "|"})$/
        key = $1
        operator = operators[$2]
      end
      
      if !magic_fields.include? key.to_sym
        
        # transform 'value' to the correct type for this key if needed
        if [:nin, :in, :all].include?(operator)
          value = value.split("|").map {|v| value_for v, model.fields[key]}
        else
          value = value_for value, model.fields[key]
        end
        
#         puts
#         puts "value: #{value.inspect} (#{value.class})"
        
        if operator
          if conditions[key].nil? or conditions[key].is_a?(Hash)
            conditions[key] ||= {}
            
            if [:lt, :lte, :gt, :gte, :ne, :in, :nin, :all, :exists].include?(operator)
              conditions[key]["$#{operator}"] = value 
            elsif operator == :match
              conditions[key] = regex_for value
            elsif operator == :match_s
              conditions[key] = regex_for value, false
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
    
    if params[:search].present? and model.respond_to?(:search_fields)
      conditions["$or"] = model.search_fields.map do |key|
        {key => regex_for(params[:search])}
      end
    end

    conditions
  end
  
  def regex_for(value, i = true)
    regex_value = value.dup
    %w{+ ? . * ^ $ ( ) [ ] { } | \ }.each {|char| regex_value.gsub! char, "\\#{char}"}
    i ? /#{regex_value}/i : /#{regex_value}/
  end
  
  def value_for(value, field)
    # type overridden in model
    if field
      if field.type == Boolean
        (value == "true") if ["true", "false"].include? value
      elsif field.type == Integer
        value.to_i
      elsif [Date, Time, DateTime].include?(field.type)
        Time.parse(value) rescue nil
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
        Time.parse(value) rescue nil
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
    
    [[key, sort]]
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

  def attributes_for(document, fields)
    attributes = document.attributes
    [:_id, :created_at, :updated_at].each {|key| attributes.delete(key) unless (fields || []).include?(key.to_s)}
    attributes
  end
  
  def results_for(model, criteria, conditions, fields)
    key = model.to_s.underscore.pluralize
    pagination = pagination_for params
    skip = pagination[:per_page] * (pagination[:page]-1)
    limit = pagination[:per_page]
    
    
    count = criteria.count
    documents = criteria.skip(skip).limit(limit).to_a
    
    {
      key => documents.map {|document| attributes_for document, fields},
      :count => count,
      :page => {
        :count => documents.size,
        :per_page => pagination[:per_page],
        :page => pagination[:page]
      }
    }
  end
  
  def explain_for(criteria, conditions, fields, order)
    pagination = pagination_for params
    skip = pagination[:per_page] * (pagination[:page]-1)
    limit = pagination[:per_page]
    
    cursor = criteria.skip(skip).limit(limit).execute
    
    {
      :conditions => conditions,
      :fields => fields,
      :order => order,
      :explain => cursor.explain,
      :count => cursor.count,
      :page => {
        :per_page => pagination[:per_page],
        :page => pagination[:page]
      }
    }
  end
  
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