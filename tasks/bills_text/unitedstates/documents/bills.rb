#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'nokogiri'

module UnitedStates
  module Documents
    class Bills

      # elements to be turned into divs (must be listed explicitly)
      BLOCKS = %w{
        legis-body resolution-body engrossed-amendment-body title
        amendment amendment-block amendment-instruction
        section subsection paragraph subparagraph subchapter clause
        quoted-block
        toc toc-entry
      }

      # elements to be turned into spans (unlisted elements default to inline)
      INLINES = %w{
        after-quoted-block quote
        internal-xref external-xref
        text header enum
        short-title official-title
      }

      # Given a path to an XML file published by the House or Senate,
      # produce an HTML version of the document at the given output.
      def self.process(text, options = {})
        doc = Nokogiri::XML text

        # let's start by just caring about the body of the bill - the legis-body
        body = doc.at("legis-body") || doc.at("resolution-body") || doc.at("engrossed-amendment-body")
        body.traverse do |node|

          # for some nodes, we'll preserve some attributes
          preserved = {}

          # <external-xref legal-doc="usc" parsable-cite="usc/12/5301"
          # cite check
          if (node.name == "external-xref") and (node.attributes["legal-doc"].value == "usc")
            preserved["data-citation-type"] = "usc"
            preserved["data-citation-id"] = node.attributes["parsable-cite"].value
          end

          # turn into a div or span with a class of its old name
          name = node.name
          if BLOCKS.include?(name)
            node.name = "div"
          else # inline
            node.name = "span"
          end
          preserved["class"] = name


          # strip out all attributes
          node.attributes.each do |key, value|
            node.attributes[key].remove
          end

          # restore just the ones we were going to preserve
          preserved.each do |key, value|
            node.set_attribute key, value
          end
        end

        body.to_html
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
  text = File.read infile

  puts UnitedStates::Documents::Bills.process text, options
end