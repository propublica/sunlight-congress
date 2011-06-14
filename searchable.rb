module Searchable

  def self.term_for(params)
    params[:query].strip.downcase
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
    fields = params.keys.select do |key| 
      !magic_fields.include?(key.to_sym) and params[key].present?
    end
    
    if fields.any?
      {
        :and => fields.map {|field| subfilter_for model, field, params[field]}
      }
    else
      nil
    end
  end
  
  def self.subfilter_for(model, field, value)
    parsed = value_for value, model.field_type(field)
    
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
      from = parsed.midnight
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
    if params[:sections].blank?
      model.result_fields.map {|field| field.to_s}
    else
      params[:sections].split(',').uniq
    end
  end
  
  def self.results_for(term, model, query, filter, fields, order, pagination, other)
    mapping = model.to_s.underscore.pluralize
    
    request = request_for query, filter, fields, order, pagination, other

    begin  
      results = search_for mapping, request
      documents = results.hits.map {|hit| attributes_for term, hit, model, fields}
      
      {
        mapping => documents,
        :count => results.total_entries,
        :page => {
          :count => documents.size,
          :per_page => pagination[:per_page],
          :page => pagination[:page]
        }
      }
    rescue ElasticSearch::RequestError => exc
      error_from exc
    end
  end
  
  def self.explain_for(term, model, query, filter, fields, order, pagination, other)
    mapping = model.to_s.underscore.pluralize
    request = request_for query, filter, fields, order, pagination, other
    
    begin
      results = search_for mapping, request
      
      {
        :request => request,
        :query => term,
        :mapping => mapping,
        :count => results.total_entries,
        :response => results.response
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
        highlight[:pre_tags] = [pre]
        highlight[:post_tags] = [post]
      end
      
      if params[:highlight_size].present?
        highlight[:fragment_size] = params[:highlight_size].to_i
      end
      
      options[:highlight] = highlight
    end
    
    options
  end
  
  def self.search_for(mapping, request)
    client = client_for mapping
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
        :fields => fields.map {|field| "_source.#{field}"}
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
    search = {:score => hit._score, :query => term}
    
    hit.fields ||= {}
    
    if hit.highlight
      search[:highlight] = hit.highlight
    end
    
    hit.fields.each do |key, value| 
      field = key.sub "_source.", ""
      #TODO: break down dot notation into a hash?
      attributes[field] = value
    end
    
    attributes.merge :search => search
  end
  
  def self.pagination_for(model, params)
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
  
  
  def self.value_for(value, type)
    # type overridden in model
    if type
      if type == Boolean
        (value == "true") if ["true", "false"].include? value
      elsif type == Integer
        value.to_i
      elsif [Date, Time, DateTime].include?(type)
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
  
  def self.original_magic_fields
    [
      :sections, :basic,
      :order, :sort, 
      :page, :per_page,
      :search, :query,
      :explain,
      :highlight, :highlight_tags, :highlight_size
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
  
  def self.client_for(mapping)
    full_host = "#{config[:elastic_search][:host]}:#{config[:elastic_search][:port]}"
    index = config[:elastic_search][:index]
    ElasticSearch.new full_host, :index => index, :type => mapping
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