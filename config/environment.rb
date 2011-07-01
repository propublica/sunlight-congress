require 'json/ext'

# hack to stop ActiveSupport from taking away my JSON C extension
[Object, Array, FalseClass, Float, Hash, Integer, NilClass, String, TrueClass].each do |klass|
  klass.class_eval do
    alias_method :to_json_from_gem, :to_json
  end
end

require 'sinatra'
require 'mongoid'
require 'tzinfo'
require 'elasticsearch'

# restore the original to_json on core objects (damn you ActiveSupport)
[Object, Array, FalseClass, Float, Hash, Integer, NilClass, String, TrueClass].each do |klass|
  klass.class_eval do
    alias_method :to_json, :to_json_from_gem
  end
end


# app-wide configuration

def config
  @config ||= YAML.load_file File.join(File.dirname(__FILE__), "config.yml")
end

configure do
  config[:mongoid][:logger] = Logger.new config[:log_file] if config[:log_file]
  Mongoid.configure {|c| c.from_hash config[:mongoid]}
  
  # This is for when people search by date (with no time), or a time that omits the time zone
  # We will assume users mean Eastern time, which is where Congress is.
  Time.zone = ActiveSupport::TimeZone.find_tzinfo "America/New_York"
end

# special fields used by the system, cannot be used on a model (on the top level)
def magic_fields
  [
    :apikey, 
    :callback, :_, # jsonp support (_ is to allow cache-busting)
    :captures # Sinatra keyword to do route parsing
  ]
end


# load in REST helpers and models
require 'queryable'
Queryable.add_magic_fields magic_fields
require 'searchable'
Searchable.add_magic_fields magic_fields
Searchable.config = config


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
  @search_route ||= /^\/search\/(#{searchable_models.map {|m| m.to_s.underscore.pluralize}.join "|"})\.(json|xml)$/
end