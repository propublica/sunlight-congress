#!/usr/bin/env ruby

require 'yaml'

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

name = "Congress API"
twitter = "sunlightlabs"


if ARGV[0]
  files = [ARGV[0]]
else
  files = %w{index legislators bills}
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
  
  # add in our own header
  content.sub! /<link.*?<\/head>/im, "#{header}\n</head>"

  # clean up what markdown does to our dt/dd blocks
  content.gsub! /<\/p>\n<dd>/m, "<dd>"
  content.gsub! "<p><dt>", "<dt>"

  # add in our own footer
  content.gsub! "</body>", "#{footer}\n</body>"

  f = File.open(output_file, "w")
  f.write content
  f.close
end