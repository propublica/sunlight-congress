module Searchable

  def self.query_for(query_string, params, search_fields)
    return unless query_string.present?

    conditions = {
      query_string: {
        query: query_string,
        default_operator: "AND",
        use_dis_max: true,
        fields: search_fields
      }
    }
  end
  
  def self.filter_for(filters)
    return nil unless filters.any?

    subfilters = filters.map do |field, filter| 
      value, operator = filter
      subfilter_for field, value, operator
    end

    if subfilters.size == 1
      subfilters.first
    else
      {
        :and => {
          filters: subfilters,
          _cache: true
        }
      }
    end
  end
  
  def self.subfilter_for(field, value, operator)
    if operator == "exists"
      base = {exists: {"field" => field.to_s}}
      if value == false
        return {"not" => base}
      else
        return base
      end
    end

    if ["all", "in"].include?(operator)
      return {
        {"all" => "and", "in" => "or"}[operator] => value.map {|v| subfilter_for field, v, nil}
      }
    end

    subfilter = if value.is_a?(String)
      # strings can be filtered on ranges
      # especially effective on date fields forced to be strings
      if ["lt", "lte", "gt", "gte"].include?(operator)
        options = {operator => value.to_s}
        {range: {field.to_s => options}}
      else
        {
          query: {
            text: {
              field.to_s => {
                query: value,
                type: "phrase"
              }
            }
          }
        }
      end

    elsif value.is_a?(Boolean)
      # nothing less nor greater than the truth
      {
        term: {
          field.to_s => value.to_s
        }
      }

    elsif value.is_a?(Fixnum)
      if ["lt", "lte", "gt", "gte"].include?(operator)
        options = {operator => value.to_s}
        {range: {field.to_s => options}}
      else
        {term: {field.to_s => value.to_s}}
      end

    elsif value.is_a?(Time)
      # ES doesn't have time-specific functions, we just
      # convert the Time back to its normal RFC 3339 (UTC)
      # format and treat it like a string
      if ["lt", "lte", "gt", "gte"].include?(operator)
        options = {operator => value.iso8601}
        {range: {field.to_s => options}}
      else
        {
          query: {
            text: {
              field.to_s => {
                query: value.iso8601,
                type: "phrase"
              }
            }
          }
        }
      end
    end

    # reverse the subfilter if there was a 'not'
    if operator == "not"
      {"not" => subfilter}
    else
      subfilter
    end
  end
  
  def self.search_fields_for(models)
    models = [models] unless models.is_a?(Array)
    models.map {|m| m.search_fields.map {|field| field.to_s}}.flatten.uniq
  end
  
  def self.raw_results_for(models, query, filter, fields, order, pagination, other)
    request = request_for models, query, filter, fields, order, pagination, other
    if other[:explain]
      @explain_client.search request[0], request[1]
    else
      @search_client.search request[0], request[1]
    end
  end

  def self.documents_for(query_string, fields, raw_results)
    raw_results.hits.map {|hit| attributes_for query_string, hit, fields}
  end

  def self.mapping_for(models)
    models.map {|m| m.to_s.underscore.pluralize}.join ","
  end
  
  def self.results_for(raw_results, documents, pagination)
    {
      results: documents,
      count: raw_results.total_entries,
      page: {
        count: documents.size,
        per_page: pagination[:per_page],
        page: pagination[:page]
      }
    }
  end
  
  def self.explain_for(query_string, models, query, filter, fields, order, pagination, other)
    # could get moved up to api handler
    request = request_for models, query, filter, fields, order, pagination, other
    mapping = mapping_for models
    
    begin
      start = Time.now
      results = @explain_client.search request[0], request[1]
      elapsed = Time.now - start

      # subject to a race condition here, need to think of a better solution than a class variable
      # but in practice, the explain mode is not going to be used in production, only debugging
      # so the chance of an actual race is low.
      last_request = ExplainLogger.last_request
      last_response = ExplainLogger.last_response
      
      {
        query: query_string,
        mapping: mapping,
        count: results.total_entries,
        elapsed: elapsed,
        request: last_request,
        response: last_response
      }
    rescue ElasticSearch::RequestError => exc
      {
        request: request,
        mapping: mapping,
        error: error_from(exc)
      }
    end
  end
  
  # remove the status code from the beginning and parse it as JSON
  def self.error_from(exception)
    JSON.parse exception.message.sub(/^\(\d+\)\s*/, '')
  end
  
  def self.other_options_for(params, search_fields)  
    options = {
      # turn on explanation fields on each hit, for the discerning debugger
      explain: params[:explain].present?,
      
      # compute a score even if the sort is not on the score
      track_scores: true
    }
      
    if params[:highlight] == "true"
      
      highlight = {
        fields: {},
        order: "score",
        fragment_size: 200
      }
      
      search_fields.each {|field| highlight[:fields][field] = {}}
      
      if params["highlight.tags"].present?
        pre, post = params["highlight.tags"].split ','
        highlight[:pre_tags] = [pre || '']
        highlight[:post_tags] = [post || '']
      end
      
      if params["highlight.size"].present?
        highlight[:fragment_size] = params["highlight.size"].to_i
      end
      
      options[:highlight] = highlight
    end
    
    options
  end
  
  def self.request_for(models, query, filter, fields, order, pagination, other)
    from = pagination[:per_page] * (pagination[:page]-1)
    size = pagination[:per_page]
    
    query_filter = {}
    if query and filter
      query_filter = {
        query: {
          filtered: {
            filter: filter,
            query: query
          }
        }
      }
    elsif query
      query_filter = {query: query}
    elsif filter
      query_filter = {filter: filter}
    else
      # uh oh?
    end
    
    sort = order.map do |field, direction|
      {field => direction}
    end
    
    [
      {
        sort: sort,
        fields: fields
      }.merge(query_filter).merge(other), 
     
      # mapping and pagination info has to go into the second hash
      {
        type: mapping_for(models),
        from: from,
        size: size
      }
    ]
  end
  
  def self.attributes_for(query_string, hit, fields)
    attributes = {}
    search = {score: hit._score, type: hit._type.singularize}
    
    hit.fields ||= {}
    
    if hit.highlight
      search[:highlight] = hit.highlight
    end
    
    hit.fields.each do |key, value| 
      break_out attributes, key.split('.'), value
    end
    
    attributes.merge search: search
  end
  
  # helper function to recursively rewrite a hash to break out dot-separated fields into sub-documents
  def self.break_out(hash, keys, final_value)
    if keys.size > 1
      first = keys.first
      rest = keys[1..-1]
      
      # default to on
      hash[first] ||= {}
      
      break_out hash[first], rest, final_value
    else
      hash[keys.first] = final_value
    end
  end  

  def self.configure_clients!
    http_host = "http://#{Environment.config['elastic_search']['host']}:#{Environment.config['elastic_search']['port']}"
    options = {
      index: Environment.config['elastic_search']['index'], 
      auto_discovery: false
    }

    @search_client = ElasticSearch.new(http_host, options) do |conn|
      conn.adapter Faraday.default_adapter
    end

    Faraday.register_middleware :response, explain_logger: ExplainLogger
    @explain_client = ElasticSearch.new(http_host, options) do |conn|
      conn.response :explain_logger
      conn.adapter Faraday.default_adapter
    end
  end

  # referenced by loading tasks
  def self.client; @search_client; end
  
  class ExplainLogger < Faraday::Response::Middleware
    def self.last_request; @@last_request; end
    def self.last_response; @@last_response; end

    def call(env)
      @@last_request = {
        body: env[:body] ? ::Oj::load(env[:body]) : nil, 
        url: env[:url].to_s
      }
      super
    end

    def on_complete(env)
      @@last_response = {
        body: env[:body] ? ::Oj::load(env[:body]) : nil,
        url: env[:url].to_s
      }
    end
  end
  
end