#!/usr/bin/env ruby

port = ARGV[0] || 9200

single = ARGV[1] || ""

mappings = (single == "") ? Dir.glob('config/elasticsearch/mappings/*.json').map {|dir| File.basename dir, File.extname(dir)} : [single]

mappings.each do |mapping|
  system "curl -XPUT 'http://localhost:#{port}/rtc_#{mapping}/'"
  puts 
  system "curl -XPUT 'http://localhost:#{port}/rtc_#{mapping}/#{mapping}/_mapping' -d @config/elasticsearch/mappings/#{mapping}.json"
  puts
  puts
end