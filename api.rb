#!/usr/bin/env ruby

require 'sinatra'

configure(:development) do |config|
  require 'sinatra/reloader'
end

get '/' do
  'Hello, World'
end