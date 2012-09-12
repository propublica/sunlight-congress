module Searchable

  def self.term_for(params)
    (params[:query] || params[:q]).strip.downcase
  end
  
  def self.query_for(term, model, params, search_fields)
    
    conditions = {
      :dis_max => {
        :queries => []
      }
    }
    
    search_fields.each do |field|
      conditions[:dis_max][:queries] << subquery_for(term, field)
    end
    
    conditions
  end

  def self.relaxed_query_for(string, model, params, search_fields)
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
        :text => {
          field => {
            :query => term,
            :type => "phrase"
          }
        }
    }
  end
  
  def self.filter_for(model, params)
    fields = {}

    params.keys.each do |key| 
      if !magic_fields.include?(key.to_sym) and params[key].present?
        fields[key] = params[key]
      end
    end

    # citation parameter dynamically inserts filter on citation field
    if params[:citation]
      fields[model.cite_field] = params[:citation]
    end
    
    if fields.any?
      {
        :and => fields.map {|field, value| subfilter_for model, field, value}
      }
    else
      nil
    end
  end
  
  def self.subfilter_for(model, field, value)
    parsed = value_for value, model.fields[field]
    
    if parsed.is_a?(String)
      {
        :query => {
          :text => {
            field.to_s => {
              :query => parsed,
              :type => "phrase"
            }
          }
        }
      }
    elsif parsed.is_a?(Fixnum)
      {
        :numeric_range => {
          field.to_s => {
            :from => parsed.to_s,
            :to => parsed.to_s
          }
        }
      }
    elsif parsed.is_a?(Boolean)
      {
        :term => {
          field.to_s => parsed.to_s
        }
      }
    elsif parsed.is_a?(Time)
      from = parsed
      to = from + 1.day
      {
        :range => {
          field.to_s => {
            :from => from.iso8601,
            :to => to.iso8601,
            :include_upper => false
          }
        }
      }
    end
  end
  
  # default to all the fields that the model declares as searchable,
  # but allow the user to limit it to a smaller subset of those fields
  def self.search_fields_for(model, params)
    default_fields = model.searchable_fields.map {|field| field.to_s}
    if params[:search].blank?
      default_fields
    else
      params[:search].split(',').uniq.select {|field| default_fields.include? field}
    end
  end
  
  def self.order_for(model, params)
    key = params[:order].present? ? params[:order].to_s : "_score"
      
    sort = nil
    if params[:sort].present? and ['desc', 'asc'].include?(params[:sort].downcase.to_s)
      sort = params[:sort].downcase.to_s
    else
      sort = 'desc'
    end
    
    [{key => sort}]
  end
  
  def self.fields_for(model, params)
    sections = if params[:fields].blank?
      model.result_fields.map {|field| field.to_s}
    else
      params[:fields].split(',').uniq
    end

    if params[:citation] and model.cite_key
      cite_key = model.cite_key.to_s
      sections << cite_key unless sections.include?(cite_key)
    end

    sections
  end

  def self.raw_results_for(term, model, query, filter, fields, order, pagination, other)
    mapping = model.to_s.underscore.pluralize
    request = request_for query, filter, fields, order, pagination, other
    search_for mapping, request
  end

  def self.documents_for(term, model, fields, raw_results)
    raw_results.hits.map {|hit| attributes_for term, hit, model, fields}
  end
  
  def self.results_for(term, model, raw_results, documents, pagination)
    mapping = model.to_s.underscore.pluralize
    
    {
      mapping => documents,
      :count => raw_results.total_entries,
      :page => {
        :count => documents.size,
        :per_page => pagination[:per_page],
        :page => pagination[:page]
      }
    }
  end
  
  def self.explain_for(term, model, query, filter, fields, order, pagination, other)
    mapping = model.to_s.underscore.pluralize
    request = request_for query, filter, fields, order, pagination, other
    
    begin
      results = search_for mapping, request, explain: other[:explain]

      # subject to a race condition here, need to think of a better solution than a class variable
      # but in practice, the explain mode is not going to be used in production, only debugging
      # so the chance of an actual race is low.
      last_request = ExplainLogger.last_request
      last_response = ExplainLogger.last_response
      
      {
        :query => term,
        :mapping => mapping,
        :count => results.total_entries,
        :request => last_request,
        :response => last_response
      }
    rescue ElasticSearch::RequestError => exc
      {
        :request => request,
        :mapping => mapping,
        :error => error_from(exc)
      }
    end
  end
  
  # remove the status code from the beginning and parse it as JSON
  def self.error_from(exception)
    JSON.parse exception.message.sub(/^\(\d+\)\s*/, '')
  end
  
  def self.other_options_for(model, params, search_fields)
    
    options = {
      # turn on explanation fields on each hit, for the discerning debugger
      :explain => params[:explain].present?,
      
      # compute a score even if the sort is not on the score
      :track_scores => true
    }
      
    if params[:highlight] == "true"
      
      highlight = {
        :fields => {},
        :order => "score",
        :fragment_size => 200
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
  
  def self.search_for(mapping, request, client_options = {})
    client = client_for mapping, client_options
    client.search request[0], request[1]
  end
  
  def self.request_for(query, filter, fields, order, pagination, other)
    from = pagination[:per_page] * (pagination[:page]-1)
    size = pagination[:per_page]
    
    if filter
      other[:filter] = filter
    end
    
    [
      {
        :query => query,
        :sort => order,
        :fields => fields
      }.merge(other), 
     
      # pagination info has to go into the second hash or rubberband messes it up
      {
        :from => from,
        :size => size
      }
    ]
  end
  
  def self.attributes_for(term, hit, model, fields)
    attributes = {}
    search = {score: hit._score, query: term}
    
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
  
  def self.pagination_for(model, params)
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
    
    {:per_page => per_page, :page => page}
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
  
  def self.client_for(document_type, options = {})
    full_host = "#{config['elastic_search']['host']}:#{config['elastic_search']['port']}"
    index = "#{config['elastic_search']['index']}"
    
    ElasticSearch.new("http://#{full_host}", :index => index, :type => document_type) do |conn|
      if options[:explain]
        conn.response :explain_logger
      end

      conn.adapter Faraday.default_adapter
    end
  end

  def self.es_index
    Tire.index config['elastic_search']['index']
  end

  class ExplainLogger < Faraday::Response::Middleware

    def self.last_request; @@last_request; end
    def self.last_response; @@last_response; end

    def call(env)
      # puts "request: #{env.inspect}\n\n"
      @@last_request = {
        body: env[:body] ? ::Oj::load(env[:body], mode: :compat) : nil, 
        url: env[:url].to_s
      }
      super
    end

    def on_complete(env)
      # puts "response: #{env.inspect}\n\n"
      @@last_response = {
        body: env[:body] ? ::Oj::load(env[:body], mode: :compat) : nil,
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