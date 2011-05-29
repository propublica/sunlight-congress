require 'sinatra'
require 'mongoid'
require 'tzinfo'


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
    :captures, # Sinatra keyword to do route parsing
    
    # the Queryable module uses these
    :sections, 
    :order, :sort, 
    :page, :per_page,
    :search, 
    :explain 
  ]
end


# load in models
require 'queryable'
Queryable.magic_fields = magic_fields

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
  @queryable_models ||= all_models.reject {|model| model.respond_to?(:api?) and !model.api?}
end

def queryable_route
  @queryable_route ||= /^\/(#{queryable_models.map {|m| m.to_s.underscore.pluralize}.join "|"})\.(json|xml)$/
end