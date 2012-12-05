module Queryable

  def self.conditions_for(filters)
    conditions = {}

    # special logic for citation (TODO: kill)
    if citation_ids = filters.delete('citation_ids')
      citation_ids = citation_ids.split "|"
      if citation_ids.size == 1
        conditions['citation_ids'] = citation_ids.first
      else
        conditions['citation_ids'] = {"$all" => citation_ids}
      end
    end

    filters.each do |field, filter|
      value, operator = filter
      operator = "ne" if operator == "not"
      conditions[field] = operator ? {"$#{operator}" => value} : value
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