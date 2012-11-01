module Searchable

  def self.term_for(params)
    (params[:query] || params[:q]).strip.downcase
  end
  
  def self.query_for(term, params, search_fields)
    
    conditions = {
      'dis_max' => {
        'queries' => []
      }
    }
    
    search_fields.each do |field|
      conditions['dis_max']['queries'] << subquery_for(term, field)
    end
    
    conditions
  end

  def self.relaxed_query_for(string, params, search_fields)
    conditions = {
      'query_string' => {
        'query' => string,
        'default_operator' => (params[:default_operator] || "AND"),
        'use_dis_max' => true,
        'fields' => search_fields
      }
    }
  end
  
  # factored out mainly for ease of unit testing
  def self.subquery_for(term, field)
    {
      text: {
        field => {
          query: term,
          type: "phrase"
        }
      }
    }
  end
  
  def self.filter_for(models, params)
    fields = {}

    params.keys.each do |key| 
      if !magic_fields.include?(key.to_sym) and params[key].present?
        fields[key] = params[key]
      end
    end

    # citation parameter dynamically inserts filter on citation field
    if params[:citation]
      fields['citation_ids'] = params[:citation]
    end
    
    return nil unless fields.any?
    subfilters = fields.map do |field, value| 
      valid_operators = [nil, "gt", "gte", "lt", "lte"]

      # field may have an operator on the end, pluck it out
      field, operator = field.split "__"
      next unless valid_operators.include?(operator)

      # value is a string, infer whether it needs casting
      models = [models] unless models.is_a?(Array)
      types = models.select {|model| model.respond_to?(:fields) and model.fields[field]}
      # for multiple models, just pick the first (no known clashes anyway)
      type = types.any? ? types.first.fields[field] : nil

      parsed = value_for value, type

      # handle citations specially
      if field == 'citation_ids'
        citation_filter_for field, value
      else
        subfilter_for field, parsed, operator
      end
    end.compact

    return nil unless subfilters.any?

    if subfilters.size == 1
      subfilters.first
    else
      # join subfilters together as an AND filter
      # use the alternate form of the AND filter that allows caching
      {
        :and => {
          :filters => subfilters,
          :_cache => true
        }
      }
    end
  end

  # the citation subfilter is itself an 'and' filter on a set of term subfilters
  def self.citation_filter_for(field, value)
    citation_ids = value.split "|"
    
    subfilters = citation_ids.map do |citation_id|
      subfilter_for field, citation_id
    end

    if subfilters.size == 1
      subfilters.first
    else
      {:and => subfilters}
    end
  end
  
  def self.subfilter_for(field, value, operator = nil)
    if value.is_a?(String)
      if operator.nil?
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

      # strings can be filtered on ranges
      # especially effective on date fields forced to be strings
      else
        options = {operator => value.to_s}
        {range: {field.to_s => options}}
      end

    elsif value.is_a?(Boolean)
      # operators don't mean anything here
      {
        term: {
          field.to_s => value.to_s
        }
      }

    elsif value.is_a?(Fixnum)
      if operator.nil?
        {term: {field.to_s => value.to_s}}
      else
        options = {operator => value.to_s}
        {range: {field.to_s => options}}
      end

    elsif value.is_a?(Time)
      if operator.nil?
        from = value
        to = from + 1.day
        options = {
          from: from.iso8601,
          to: to.iso8601,
          include_upper: false
        }
      else
        options = {operator => value.iso8601}
      end

      {range: {field.to_s => options}}
    end
  end
  
  # default to all the fields that the model declares as searchable,
  # but allow the user to limit it to a smaller subset of those fields
  def self.search_fields_for(models, params)
    models = [models] unless models.is_a?(Array)

    default_fields = models.map {|m| m.searchable_fields.map {|field| field.to_s}}.flatten.uniq
    if params[:search].blank?
      default_fields
    else
      params[:search].split(',').uniq.select {|field| default_fields.include? field}
    end
  end
  
  def self.order_for(params)
    key = params[:order].present? ? params[:order].to_s : "_score"
      
    sort = nil
    if params[:sort].present? and ['desc', 'asc'].include?(params[:sort].downcase.to_s)
      sort = params[:sort].downcase.to_s
    else
      sort = 'desc'
    end
    
    [{key => sort}]
  end
  
  def self.fields_for(models, params)
    models = [models] unless models.is_a?(Array)

    sections = if params[:fields].blank?
      models.map {|model| model.result_fields.map {|field| field.to_s}}.flatten
    else
      params[:fields].split ','
    end

    if params[:citation]
      models.each do |model|
        next unless model.cite_key
        cite_key = model.cite_key.to_s
        sections << cite_key
      end
    end

    sections.uniq
  end

  def self.raw_results_for(term, models, query, filter, fields, order, pagination, other)
    request = request_for models, query, filter, fields, order, pagination, other
    search_for request
  end

  def self.documents_for(term, fields, raw_results)
    raw_results.hits.map {|hit| attributes_for term, hit, fields}
  end

  def self.mapping_for(models)
    models.map {|m| m.to_s.underscore.pluralize}.join ","
  end
  
  def self.results_for(term, models, raw_results, documents, pagination)
    document_type = (models.size == 1) ? mapping_for(models) : "results"
    {
      document_type => documents,
      count: raw_results.total_entries,
      page: {
        count: documents.size,
        per_page: pagination[:per_page],
        page: pagination[:page]
      }
    }
  end
  
  def self.explain_for(term, models, query, filter, fields, order, pagination, other)
    request = request_for models, query, filter, fields, order, pagination, other
    mapping = mapping_for models
    
    begin
      start = Time.now
      results = search_for request, explain: other[:explain]
      elapsed = Time.now - start

      # subject to a race condition here, need to think of a better solution than a class variable
      # but in practice, the explain mode is not going to be used in production, only debugging
      # so the chance of an actual race is low.
      last_request = ExplainLogger.last_request
      last_response = ExplainLogger.last_response
      
      {
        query: term,
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
      
      if params[:highlight_tags].present?
        pre, post = params[:highlight_tags].split ','
        highlight[:pre_tags] = [pre || '']
        highlight[:post_tags] = [post || '']
      end
      
      if params[:highlight_size].present?
        highlight[:fragment_size] = params[:highlight_size].to_i
      end
      
      options[:highlight] = highlight
    end
    
    options
  end
  
  def self.search_for(request, client_options = {})
    # client_options only used for explain at this time
    if client_options[:explain]
      explain.search request[0], request[1]
    else
      # thrift transport may need to reconnect if ES is restarted
      if thrift?
        begin
          thrift.search request[0], request[1]
        rescue IOError, ElasticSearch::ConnectionFailed => ex
          if (ex.message =~ /closed stream/) or (ex.message =~ /Broken pipe/)
            # reset clients
            configure_clients! 

            # only one retry, no rescue
            thrift.search request[0], request[1]
          else
            raise ex
          end
        end

      # use http client, don't be so forgiving
      else 
        client.search request[0], request[1]
      end
    end
  end
  
  def self.request_for(models, query, filter, fields, order, pagination, other)
    from = pagination[:per_page] * (pagination[:page]-1)
    size = pagination[:per_page]
    
    if filter
      query = {
        filtered: {
          filter: filter,
          query: query
        }
      }
    end
    
    [
      {
        query: query,
        sort: order,
        fields: fields
      }.merge(other), 
     
      # mapping and pagination info has to go into the second hash
      {
        type: mapping_for(models),
        from: from,
        size: size
      }
    ]
  end
  
  def self.attributes_for(term, hit, fields)
    attributes = {}
    search = {score: hit._score, query: term, type: hit._type.singularize}
    
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
  
  
  def self.value_for(value, type)
    # type overridden in model
    if type
      if type == Boolean
        (value == "true") if ["true", "false"].include? value
      elsif type == Integer
        value.to_i
      elsif [Date, Time, DateTime].include?(type)
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
      elsif value =~ /^\d\d\d\d-\d\d-\d\d$/
        Time.zone.parse(value).utc rescue nil
      elsif value =~ /^\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d/
        # compress times to act like dates until we support ranges
        Time.zone.parse(value).midnight.utc rescue nil
      else
        value
      end
    end
  end
  
  def self.original_magic_fields
    [
      :search, 
      :query, :q,
      :highlight, :highlight_tags, :highlight_size,
      :default_operator
    ]
  end
  
  def self.add_magic_fields(fields)
    @extra_magic_fields = fields
  end
  
  def self.magic_fields
    (@extra_magic_fields || []) + original_magic_fields
  end
  
  def self.config=(config)
    @config = config
  end
  
  def self.config
    @config
  end

  # http client
  def self.client=(client)
    @client = client
  end

  def self.client
    @client
  end

  # thrift client
  def self.thrift=(thrift)
    @thrift = thrift
  end

  def self.thrift
    @thrift
  end

  # explain client (http + middleware)
  def self.explain=(client)
    @explain = client
  end

  def self.explain
    @explain
  end

  def self.thrift?
    config['elastic_search']['thrift'].present?
  end

  # load and persist search clients
  def self.configure_clients!
    http_host = "http://#{config['elastic_search']['host']}:#{config['elastic_search']['port']}"
    options = {
      index: config['elastic_search']['index'], 
      auto_discovery: false
    }

    Faraday.register_middleware :response, explain_logger: Searchable::ExplainLogger
    Faraday.register_middleware :response, debug_request: Searchable::DebugRequest
    Faraday.register_middleware :response, debug_response: Searchable::DebugResponse

    Searchable.config = config

    if thrift?
      thrift_host = "#{config['elastic_search']['host']}:#{config['elastic_search']['thrift']}"
      Searchable.thrift = ElasticSearch.new thrift_host, options.merge(transport: ElasticSearch::Transport::Thrift)
    end

    Searchable.client = ElasticSearch.new(http_host, options) do |conn|
      # conn.response :debug_request # print request to STDOUT
      # conn.response :debug_response # print response to STDOUT
      conn.adapter Faraday.default_adapter
    end

    Searchable.explain = ElasticSearch.new(http_host, options) do |conn|
      conn.response :explain_logger # store last request and response for explain output
      conn.adapter Faraday.default_adapter
    end
  end
  
  class DebugRequest < Faraday::Response::Middleware
    def call(env)
      puts "\nrequest: #{env.inspect}\n\n"
      super
    end
  end

  class DebugResponse < Faraday::Response::Middleware
    def on_complete(env)
      puts "\nresponse: #{env.inspect}\n\n"
    end
  end

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

  module Model
    
    module ClassMethods
      
      def result_fields(*fields)
        if fields.any?
          @result_fields = fields
        else
          @result_fields
        end
      end
      
      def searchable_fields(*fields)
        if fields.any?
          @searchable_fields = fields
        else
          @searchable_fields
        end
      end
      
      # a way of overriding assumptions about a field's type, like Mongoid provides
      def field_type(name, type = nil)
        @fields ||= {}
        if type
          @fields[name.to_s] = type
        else
          @fields[name.to_s]
        end
      end
      
      def searchable?
        true
      end
    end
    
    def self.included(base)
      base.extend ClassMethods
    end
  end
  
end