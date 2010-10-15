require 'sinatra'
require 'mongoid'

def config
  @config ||= YAML.load_file 'config/config.yml'
end

configure do
  Mongoid.configure do |mongoid|
    mongoid.from_hash config[:mongoid][ENV['RACK_ENV'] || 'development']
    mongoid.logger = nil
  end
end

Dir.glob('models/*.rb').each {|model| load model}