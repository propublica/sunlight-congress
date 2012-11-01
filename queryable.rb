module Queryable
  
  def self.fields_for(model, params)
    return nil if params[:fields].blank?
    
    sections = params[:fields].split ','
    
    if sections.include?('basic')
      sections.delete 'basic' # does nothing if not present
      sections += model.basic_fields.map {|field| field.to_s}
    end

    if params[:citation] and model.cite_key
      sections << model.cite_key.to_s
    end

    sections.uniq
  end
  
  def self.conditions_for(model, params)
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
    
    if params[:search].present? and model.search_fields
      conditions["$or"] = model.search_fields.map do |key|
        {key => regex_for(params[:search])}
      end
    end

    if params[:citation].present? and model.cite_key
      citation_ids = params[:citation].split "|"
      if citation_ids.size == 1
        criteria = citation_ids.first
      else
        criteria = {"$all" => citation_ids}
      end
        
      conditions['citation_ids'] = criteria
    end

    conditions
  end
  
  def self.order_for(model, params)
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

  def self.attributes_for(document, fields)
    attributes = document.attributes

    # 'indexed' is a special field used to help sync docs between mongodb and elasticsearch
    exclude_fields = ['_id', 'created_at', 'updated_at', 'indexed']

    exclude_fields.each {|key| attributes.delete(key) unless (fields || []).include?(key.to_s)}
    attributes
  end
  
  def self.documents_for(model, criteria, fields)
    documents = criteria.to_a
    documents.map {|document| attributes_for document, fields}
  end

  def self.results_for(model, criteria, documents, pagination)
    count = criteria.count
    key = model.to_s.underscore.pluralize
    
    {
      key => documents,
      count: count,
      page: {
        count: documents.size,
        per_page: pagination[:per_page],
        page: pagination[:page]
      }
    }
  end
  
  def self.explain_for(model, conditions, fields, order, pagination)
    criteria = criteria_for model, conditions, fields, order, pagination
    
    {
      conditions: conditions,
      fields: fields,
      order: order,
      explain: criteria.explain,
      count: criteria.count,
      page: {
        per_page: pagination[:per_page],
        page: pagination[:page]
      }
    }
  end
  
  def self.criteria_for(model, conditions, fields, order, pagination)
    skip = pagination[:per_page] * (pagination[:page]-1)
    limit = pagination[:per_page]
    
    model.where(conditions).only(fields).order_by(order).skip(skip).limit(limit)
  end
  
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
  
  def self.regex_for(value, i = true)
    regex_value = value.to_s.dup
    %w{+ ? . * ^ $ ( ) [ ] { } | \ }.each {|char| regex_value.gsub! char, "\\#{char}"}
    i ? /#{regex_value}/i : /#{regex_value}/
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
  
  def self.original_magic_fields
    [
      :search
    ]
  end
  
  def self.add_magic_fields(fields)
    @extra_magic_fields = fields
  end
  
  def self.magic_fields
    (@extra_magic_fields || []) + original_magic_fields
  end
  
  # inside a queryable model, do:
  # include Queryable::Model
  module Model
    module ClassMethods
      
      def cite_key(field = nil)
        if field
          @cite_key = field
        else
          @cite_key
        end
      end

      def default_order(order = nil)
        if order
          @default_order = order
        else
          @default_order
        end
      end
      
      def basic_fields(*fields)
        if fields.any?
          @basic_fields = fields
        else
          @basic_fields
        end
      end
      
      def search_fields(*fields)
        if fields.any?
          @search_fields = fields
        else
          @search_fields
        end
      end
      
      def queryable?
        true
      end
    end
    
    def self.included(base)
      base.extend ClassMethods
    end
  end
  
end