#!/usr/bin/env ruby

# Before use: copy config.yml.example to config.yml, and fill in the Google Analytics key.

# Usage:
# 
# Compile all .md scripts in this directory:
#   ./compile.rb 
#
# Compile a particular .md script in this directory:
#   ./compile.rb index
# or:
#   ./compile.rb index.md

require 'yaml'

unless File.exist?("config.yml")
  puts "Copy config.yml.example to config.yml and fill it in before running."
  exit
end

google_analytics = YAML.load(open("config.yml"))['google_analytics']

header = '
  <link rel="stylesheet" type="text/css" href="documentup.css">
  <script type="text/javascript" src="//use.typekit.net/egj6wnp.js"></script>
  <script type="text/javascript">try{Typekit.load();}catch(e){}</script>
'

footer = "
<script type=\"text/javascript\">

  var _gaq = _gaq || [];
  _gaq.push(['_setAccount', '#{google_analytics}']);
  _gaq.push(['_trackPageview']);

  (function() {
    var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
    ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
    var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
  })();

</script>
"

name = "Sunlight Congress API"
twitter = "sunlightlabs"


if ARGV[0]
  files = [File.basename(ARGV[0], ".md")]
else
  files = Dir.glob("*.md").map {|f| File.basename f, ".md"}
end

output_dir = ".."

files.each do |filename|
  output_file = "#{output_dir}/#{filename}.html"
  system "curl -X POST \
    --data-urlencode content@#{filename}.md \
    --data-urlencode name=\"#{name}\" \
    --data-urlencode twitter=#{twitter} \
    --data-urlencode google_analytics=\"#{google_analytics}\" \
    \"http://documentup.com/compiled\" > #{output_file}"

  content = File.read output_file
  
  # add in our own header (custom styles)
  content.sub! /<link.*?<\/head>/im, "#{header}\n</head>"

  # add in our own footer (Google Analytics)
  content.gsub! "</body>", "#{footer}\n</body>"

  # link the main header to the index page
  content.gsub! "<a href=\"#\" id=\"logo\">", "<a href=\"index.html\" id=\"logo\">"

  # custom title for non-index pages
  if filename != "index"
    title = filename.split("_").map(&:capitalize).join " "
    content.gsub! "<title>#{name}</title>", "<title>#{name} | #{title}</title>"
  end

  # get rid of braces around unindented (partial) JSON blocks
  content.gsub!(/(<code class=\"json\">){\s*\n([^\s])(.*?)}(<\/code>)/im) { [$1, $2, $3, $4].join("") }

  File.open(output_file, "w") {|file| file.write content}
end