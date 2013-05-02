#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'nokogiri'

module UnitedStates
  module Documents
    class FederalRegister

      # can treat abstract and full text the same way
      # can treat proposed and final rules the same way
      def self.process(text, options = {})
        options[:class] ||= "federal_register"


        doc = Nokogiri::HTML text

        # nokogiri generates a body tag - by changing it, we can use it as a container,
        # and also suppress the html tag from being output (for some reason)
        return "" unless body = doc.at("body")

        body.name = "div"
        body.set_attribute 'class', options[:class]

        body.traverse do |node|

          # remove the tooltip div
          if node['id'] == "window-resizer-tooltip"
            node.remove
            next
          end
          
          # remove certain attributes
          ['target', 'onclick'].each do |key|
            node.attributes[key].remove if node.attributes[key]
          end

          if node.attributes['id']
            node.set_attribute 'data-id', node.attributes['id'].value
            node.attributes['id'].remove
          end

          # detect (already-detected by FR.gov) citations, extract info from link
          # (leave original link intact)
          if (node.name == "a")
            classes = node.attributes['class']
            link = node.attributes['href'] ? node.attributes['href'].value : nil

            # fix relative links
            if link and link.start_with?("/")
              node.set_attribute "href", "https://www.federalregister.gov#{link}"
            end

            if classes and classes.value["external"]
              # Public laws
              # e.g. http://api.fdsys.gov/link?collection=plaw&congress=107&lawtype=public&lawnum=347&link-type=html
              if classes.value["publ"]
                node.set_attribute 'data-congress', link.scan(/[^\w]congress=(\d+)/).first.first
                node.set_attribute 'data-number', link.scan(/[^\w]lawnum=(\d+)/).first.first

              # US Code
              # e.g. http://api.fdsys.gov/link?collection=uscode&title=5&year=mostrecent&section=601&type=usc&link-type=html
              elsif classes.value["usc"]
                node.set_attribute 'data-title', link.scan(/[^\w]title=([\d\w]+)/).first.first
                node.set_attribute 'data-section', link.scan(/[^\w]section=([\d\w]+)/).first.first

              # CFR
              # e.g. https://www.federalregister.gov/select-citation/2013/04/30/13-CFR-121.201
              elsif classes.value["cfr"]
                part, section = link.scan(/\/([a-zA-Z0-9]+)\-CFR\-(.*?)$/).first
                node.set_attribute 'data-part', part
                node.set_attribute 'data-section', section
              end
            end

          end
        end

        # frustrating to return it in ASCII, but this preserves html entities
        body.to_html encoding: "US-ASCII"
      end

    end
  end
end

if $0 == __FILE__
  options = {}
  
  infile = ARGV[0]

  (ARGV[1..-1] || []).each do |arg|
    if arg.start_with?("--")
      if arg["="]
        key, value = arg.split('=')
      else
        key, value = [arg, true]
      end
      
      key = key.split("--")[1]
      if value == 'true'
        value = true
      elsif value == 'False'
        value = false
      end
      options[key.downcase.to_sym] = value
    end
  end

  outfile = options.delete :out
  text = File.open(infile, 'r').read

  output = UnitedStates::Documents::FederalRegister.process text, options
  if outfile
    File.open(outfile, "w") {|f| f.write output}
    puts "Written to #{outfile}."
  else
    puts output
  end
end