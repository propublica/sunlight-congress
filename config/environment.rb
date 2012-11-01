require 'oj'
require 'sinatra'
require 'mongoid'
require 'tzinfo'
require 'rubberband'


# insist on my API-wide timestamp format
Time::DATE_FORMATS.merge!(:default => Proc.new {|t| t.xmlschema})


# workhorse API handlers
require './queryable'
require './searchable'


# app-wide configuration

def config
  @config ||= YAML.load_file File.join(File.dirname(__FILE__), "config.yml")
end


configure do
  # configure mongodb client
  Mongoid.load! File.join(File.dirname(__FILE__), "mongoid.yml")
  
  Searchable.config = config
  Searchable.configure_clients!
  
  # This is for when people search by date (with no time), or a time that omits the time zone
  # We will assume users mean Eastern time, which is where Congress is.
  Time.zone = ActiveSupport::TimeZone.find_tzinfo "America/New_York"

  # insist on using the time format I set as the Ruby default,
  # even in dependent libraries that use MultiJSON (e.g. rubberband)
  Oj.default_options = {mode: :compat, time_format: :ruby}
end

# special fields used by the system, cannot be used on a model (on the top level)
def magic_fields
  [
    # common parameters
    :sections, :fields,
    :order, :sort, 
    :page, :per_page,
    :explain,

    # citation fields
    :citation, :citations, :citation_details,

    # can't use these as field names, even though they're not used as params
    :basic,

    :apikey, # API key gating
    :callback, :_, # jsonp support (_ is to allow cache-busting)
    :captures, :splat # Sinatra keywords to do route parsing
  ]
end


# load in REST helpers and models
Queryable.add_magic_fields magic_fields
Searchable.add_magic_fields magic_fields


@all_models = []
Dir.glob('models/*.rb').each do |filename|
  load filename
  model_name = File.basename filename, File.extname(filename)
  @all_models << model_name.camelize.constantize
end

def all_models
  @all_models
end


def queryable_models
  @queryable_models ||= all_models.select {|model| model.respond_to?(:queryable?) and model.queryable?}
end

def queryable_route
  @queryable_route ||= /^\/(#{queryable_models.map {|m| m.to_s.underscore.pluralize}.join "|"})\.(json|xml)$/
end

def searchable_models
  @search_models ||= all_models.select {|model| model.respond_to?(:searchable?) and model.searchable?}
end

def searchable_route
  @search_route ||= /^\/search\/((?:(?:#{searchable_models.map {|m| m.to_s.underscore.pluralize}.join "|"}),?)+)\.(json|xml)$/
end