require 'sinatra'
require 'mongoid'

def config
  @config ||= YAML.load_file 'config/config.yml'
end

def models
  @models ||= []
end

configure do
  Mongoid.configure {|c| c.from_hash config[:mongoid]}
end

Dir.glob('models/*.rb') do |filename|
  load filename
  
  model_name = File.basename filename, File.extname(filename)
  model = model_name.camelize.constantize
  models << model_name unless model.respond_to?(:api?) and !model.api?
end