module Queryable

  def self.conditions_for(model, query, filters, params)
    conditions = {}

    # special case: default to in_office legislators
    # allow it to be overridden
    if model == Legislator
      conditions['in_office'] = true
    end

    filters.each do |field, filter|
      value, operator = filter
      operator = "ne" if operator == "not"
      conditions[field] = operator ? {"$#{operator}" => value} : value
    end

    if query.present? and model.search_fields
      conditions["$or"] = model.search_fields.map do |key|
        {key => regex_for(query)}
      end
    end

    # don't allow it to be overridden if we've allowed pagination to be turned off though
    if (model == Legislator) and (params[:per_page] == "all")
      conditions['in_office'] = true
    end

    conditions
  end
  
  def self.regex_for(value)
    regex_value = value.to_s.dup
    %w{+ ? . * ^ $ ( ) [ ] { } | \ }.each {|char| regex_value.gsub! char, "\\#{char}"}
    /#{regex_value}/i
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
    criteria = model.where(conditions).only(fields).order_by(order)

    if pagination[:per_page] and pagination[:page]
      skip = pagination[:per_page] * (pagination[:page]-1)
      limit = pagination[:per_page]
      criteria.skip(skip).limit(limit)
    else
      criteria
    end
  end
end