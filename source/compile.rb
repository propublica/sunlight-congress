#!/usr/bin/env ruby

header = '
  <link rel="stylesheet" type="text/css" href="documentup.css">
  <script type="text/javascript" src="//use.typekit.net/egj6wnp.js"></script>
  <script type="text/javascript">try{Typekit.load();}catch(e){}</script>'

name = "Congress API"
twitter = "sunlightlabs"


if ARGV[0]
  files = [ARGV[0]]
else
  files = %w{index legislators}
end

output_dir = ".."

files.each do |filename|
  output_file = "#{output_dir}/#{filename}.html"
  system "curl -X POST \
    --data-urlencode content@#{filename}.md \
    --data-urlencode name=\"#{name}\" \
    --data-urlencode twitter=#{twitter} \
    \"http://documentup.com/compiled\" > #{output_file}"

  content = File.read output_file
  
  # add in our own header
  content.sub! /<link.*?<\/head>/im, "#{header}\n</head>"

  # clean up what markdown does to our dt/dd blocks
  content.gsub! /<\/p>\n<dd>/m, "<dd>"
  content.gsub! "<p><dt>", "<dt>"

  f = File.open(output_file, "w")
  f.write content
  f.close
end