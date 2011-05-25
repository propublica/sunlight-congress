require 'sinatra'
require 'mongoid'
require 'tzinfo'

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

Dir.glob(File.join(File.dirname(__FILE__), "../models/*.rb")) {|filename| load filename}

# special fields used by the system, cannot be used on a model (on the top level)
def magic_fields
  [
    :apikey, 
    :sections, 
    :order, :sort, 
    :captures, # Sinatra keyword to do route parsing
    :page, :per_page,
    :callback, :_, # jsonp support (_ is to allow cache-busting)
    :search, 
    :explain 
  ]
end

def main_route
  models = []
  Dir.glob('models/*.rb').each do |filename|
    model_name = File.basename filename, File.extname(filename)
    model = model_name.camelize.constantize
    models << model_name unless model.respond_to?(:api?) and !model.api?
  end
  models
  
  @main_route ||= /^\/(#{models.map(&:pluralize).join "|"})\.(json|xml)$/
end

# reload in development without starting server
configure(:development) do |config|
  require 'sinatra/reloader'
  config.also_reload "config/environment.rb"
  config.also_reload "analytics/*.rb"
  config.also_reload "models/*.rb"
end