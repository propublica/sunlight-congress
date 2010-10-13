#!/usr/bin/env ruby

require 'environment'

configure(:development) do |config|
  require 'sinatra/reloader'
end

get '/' do
  Legislator.first.bioguide_id
end