#!/usr/bin/env ruby

port = ARGV[0] || 9200

single = ARGV[1] || ""

mappings = (single == "") ? Dir.glob('config/elasticsearch/mappings/*.json').map {|dir| File.basename dir, File.extname(dir)} : [single]

# ensure index exists
system "curl -XPUT 'http://localhost:#{port}/rtc/'"
puts 

mappings.each do |mapping|
  system "curl -XPUT 'http://localhost:#{port}/rtc/#{mapping}/_mapping' -d @config/elasticsearch/mappings/#{mapping}.json"
  puts
  puts
end