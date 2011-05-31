#!/usr/bin/env ruby

require 'test/unit'
require 'rubygems'
require 'bundler/setup'

require File.join File.dirname(__FILE__), "../config/environment"
require File.join File.dirname(__FILE__), "../searchable"


class SearchableTest < Test::Unit::TestCase
  
  class Person
    include Searchable::Model
    
    result_fields :name, :born_at
    searchable_fields :name, :long_bio
  end
  
#   def test_fields_for_returns_nil_if_sections_is_blank
#     assert_nil Searchable.fields_for Person, {:sections => ""}
#     assert_nil Searchable.fields_for Person, {:sections => nil}
#     assert_nil Searchable.fields_for Person, {}
#   end
#   
#   def test_fields_for_splits_on_a_comma
#     fields = Searchable.fields_for Person, :sections => "name,whatever,sox"
#     assert_equal ['name', 'whatever', 'sox'].sort, fields.sort
#   end
#   
#   def test_fields_for_breaks_out_basic_fields
#     fields = Searchable.fields_for Person, :sections => "basic,whatever,sox"
#     assert_equal ["name", "bio", "born_at", "whatever", "sox"].sort, fields.sort
#   end
#   
#   def test_fields_for_eliminates_dupes
#     fields = Searchable.fields_for Person, :sections => "basic,name,name,sox,bio"
#     assert_equal ["name", "bio", "born_at", "sox"].sort, fields.sort
#   end
  
  def test_fields_for_returns_result_fields
    assert_equal ["name", "born_at"].sort, Searchable.fields_for(Person, {:sections => ""}).sort
    assert_equal ["name", "born_at"].sort, Searchable.fields_for(Person, {:sections => nil}).sort
    assert_equal ["name", "born_at"].sort, Searchable.fields_for(Person, {}).sort
    assert_equal ["name", "born_at"].sort, Searchable.fields_for(Person, {:sections => "name,born_at,something"}).sort
  end
    
end