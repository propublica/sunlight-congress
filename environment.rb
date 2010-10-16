require 'sinatra'
require 'mongoid'

def config
  @config ||= YAML.load_file 'config/config.yml'
end

def models
  @models ||= []
end

Dir.glob('models/*.rb').each do |model| 
  load model
  models << File.basename(model, File.extname(model))
end

configure do
  Mongoid.configure {|c| c.from_hash config[:mongoid]}
end