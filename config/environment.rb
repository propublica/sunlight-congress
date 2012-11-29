require 'oj'
require 'sinatra'
require 'mongoid'
require 'tzinfo'
require 'rubberband'

class Api

  def self.format_for(params)
    params[:format] || "json"
  end

  def self.fields_for(models, params)
    models = [models] unless models.is_a?(Array)

    fields = if params[:fields].blank?
      models.map {|model| model.basic_fields.map {|field| field.to_s}}.flatten
    else
      params[:fields].split ','
    end

    models.each do |model|
      if model.cite_key
        fields << model.cite_key.to_s
      end
    end

    fields.uniq
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
      elsif (value =~ /^\d\d\d\d-\d\d-\d\d$/)
        Time.zone.parse(value).utc rescue nil
      else
        value
      end
    end
  end

  def self.config
    @config ||= YAML.load_file File.join(File.dirname(__FILE__), "config.yml")
  end

  # special fields used by the system, cannot be used on a model (on the top level)
  def self.magic_fields
    [
      :model, :fields,
      :order, :sort, 
      :page, :per_page,
      
      :query, :search,
      :highlight, :highlight_tags, :highlight_size, # tokill

      :citing, # citing.details
      :citation, :citation_details, # tokill

      :explain, 
      :format, # undocumented XML support

      :apikey, # API key gating
      :callback, :_, # jsonp support (_ is to allow cache-busting)
      :captures, :splat # Sinatra keywords to do route parsing
    ]
  end

  # installs a few methods when Api::Model is mixed in
  module Model
    module ClassMethods
      def publicly(*types); types.any? ? @publicly = types : @publicly; end
      def basic_fields(*fields); fields.any? ? @basic_fields = fields : @basic_fields; end
      def search_fields(*fields); fields.any? ? @search_fields = fields : @search_fields; end
      def cite_key(key = nil); key ? @cite_key = key : @cite_key; end
    end
    def self.included(base); base.extend ClassMethods; end
  end
  
end


# workhorse API handlers
require './queryable'
require './searchable'


configure do
  # configure mongodb client
  Mongoid.load! File.join(File.dirname(__FILE__), "mongoid.yml")
  
  Searchable.configure_clients! Api.config
  
  # insist on my API-wide timestamp format
  Time::DATE_FORMATS.merge!(:default => Proc.new {|t| t.xmlschema})

  # This is for when people search by date (with no time), or a time that omits the time zone
  # We will assume users mean Eastern time, which is where Congress is.
  Time.zone = ActiveSupport::TimeZone.find_tzinfo "America/New_York"

  # insist on using the time format I set as the Ruby default,
  # even in dependent libraries that use MultiJSON (e.g. rubberband)
  Oj.default_options = {mode: :compat, time_format: :ruby}
end

@models = []
Dir.glob('models/*.rb').each do |filename|
  load filename
  model_name = File.basename filename, File.extname(filename)
  @models << model_name.camelize.constantize
end
def models; @models; end

def queryable_route
  queryable = models.select {|model| model.respond_to?(:publicly) and model.publicly.include?(:queryable)}
  @queryable_route ||= /^\/(#{queryable.map {|m| m.to_s.underscore.pluralize}.join "|"})$/
end

def searchable_route
  searchable = models.select {|model| model.respond_to?(:publicly) and model.publicly.include?(:searchable)}
  @search_route ||= /^\/search\/((?:(?:#{searchable.map {|m| m.to_s.underscore.pluralize}.join "|"}),?)+)$/
end