#!/usr/bin/env ruby

header = '
  <link rel="stylesheet" type="text/css" href="documentup.css">
  <script type="text/javascript" src="//use.typekit.net/egj6wnp.js"></script>
  <script type="text/javascript">try{Typekit.load();}catch(e){}</script>'

name = "Congress API"
twitter = "sunlightlabs"

files = %w{index}

output_dir = ".."

files.each do |filename|
  output_file = "#{output_dir}/#{filename}.html"
  system "curl -X POST \
    --data-urlencode content@#{filename}.md \
    --data-urlencode name=\"#{name}\" \
    --data-urlencode twitter=#{twitter} \
    \"http://documentup.com/compiled\" > #{output_file}"

  content = File.read output_file
  content = content.sub /<link.*?<\/head>/im, "#{header}\n</head>"
  f = File.open(output_file, "w")
  f.write content
  f.close
end