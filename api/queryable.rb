module Api::Queryable
  
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
      
      if !Api.magic_fields.include? key.to_sym
        # transform 'value' to the correct type for this key if needed
        if [:nin, :in, :all].include?(operator)
          value = value.split("|").map {|v| Api.value_for v}
        else
          value = Api.value_for value
        end
        
        if operator
          if conditions[key].nil? or conditions[key].is_a?(Hash)
            conditions[key] ||= {}
            
            if [:lt, :lte, :gt, :gte, :ne, :in, :nin, :all, :exists].include?(operator)
              conditions[key]["$#{operator}"] = value
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
    key = params[:order].present? ? params[:order].to_sym : :_id
    
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

    exclude_fields = ['_id', 'created_at', 'updated_at']

    exclude_fields.each {|key| attributes.delete(key) unless (fields || []).include?(key.to_s)}
    attributes
  end
  
  def self.documents_for(model, criteria, fields)
    documents = criteria.to_a
    documents.map {|document| attributes_for document, fields}
  end

  def self.results_for(criteria, documents, pagination)
    count = criteria.count
    
    {
      results: documents,
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
    
    start = Time.now
    criteria.to_a
    elapsed = Time.now - start

    {
      conditions: conditions,
      fields: fields,
      order: order,
      explain: criteria.explain,
      count: criteria.count,
      elapsed: elapsed,
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
end