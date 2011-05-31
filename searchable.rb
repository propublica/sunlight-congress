module Searchable

  
  def self.conditions_for(model, params, search_fields)
    term = params[:query].strip.downcase
    
    conditions = {
      :dis_max => {
        :queries => []
      }
    }
    
    search_fields.each do |field|
      conditions[:dis_max][:queries] << {
        :text => {
          field => {
            :query => term,
            :type => "phrase"
          }
        }
      }
    end
    
    conditions
    # then assemble the filters (TODO)
  end
  
  def self.search_fields_for(model, params)
    model.searchable_fields.map &:to_s
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
  
  def self.results_for(model, conditions, fields, order, pagination, other)
    mapping = model.to_s.underscore.pluralize
    
    request = request_for conditions, fields, order, pagination, other
    results = search_for mapping, request
    
    documents = results.hits.map {|hit| attributes_for hit, model, fields}
    
    {
      mapping => documents,
      :count => results.total_entries,
      :page => {
        :count => documents.size,
        :per_page => pagination[:per_page],
        :page => pagination[:page]
      }
    }
  end
  
  def self.explain_for(model, conditions, fields, order, pagination, other)
    mapping = model.to_s.underscore.pluralize
    
    request = request_for conditions, fields, order, pagination, other
    results = search_for mapping, request
    
    {
      :request => request,
      :mapping => mapping,
      :count => results.total_entries,
      :response => results.response
    }
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
        :order => "score"
      }
      
      search_fields.each {|field| highlight[:fields][field] = {}}
      options[:highlight] = highlight
      
      if params[:highlight_tags].present?
        pre, post = params[:highlight_tags].split ','
        highlight[:pre_tags] = [pre]
        highlight[:post_tags] = [post]
      end
    end
    
    options
  end
  
  def self.search_for(mapping, request)
    client = client_for mapping
    client.search request[0], request[1]
  end
  
  def self.request_for(conditions, fields, order, pagination, other)
    from = pagination[:per_page] * (pagination[:page]-1)
    size = pagination[:per_page]
    
    [
      {
        :query => conditions,
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
  
  def self.attributes_for(hit, model, fields)
    attributes = {}
    search = {:score => hit._score}
    
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
      :highlight, :highlight_tags
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