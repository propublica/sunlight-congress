#!/usr/bin/env ruby

require 'test/unit'
require 'rubygems'
require 'bundler/setup'

require File.join File.dirname(__FILE__), "../config/environment"
require File.join File.dirname(__FILE__), "../searchable"


class SearchableTest < Test::Unit::TestCase
  
  class Person
    include Searchable::Model
    
    result_fields :name, :born_at, :ssn
    searchable_fields :name, :bio
  end
  
  def test_fields_for_returns_result_fields_if_sections_is_blank
    fields = Person.result_fields.map &:to_s
    assert_equal fields.sort, Searchable.fields_for(Person, {:sections => ""}).sort
    assert_equal fields.sort, Searchable.fields_for(Person, {:sections => nil}).sort
    assert_equal fields.sort, Searchable.fields_for(Person, {}).sort
  end
  
  def test_fields_for_allows_fields_outside_result_fields
    fields = Searchable.fields_for Person, :sections => "name,born_at,sox"
    assert_equal ['name', 'born_at', 'sox'].sort, fields.sort
    
    # also make sure 'basic' is ignored, has no special meaning here
    fields = Searchable.fields_for Person, :sections => "basic,name"
    assert_equal ["name", "basic"].sort, fields.sort
  end
   
  def test_fields_for_splits_on_a_comma
    fields = Searchable.fields_for Person, :sections => "name,born_at,anything"
    assert_equal ['name', 'born_at', 'anything'].sort, fields.sort
  end
   
  def test_fields_for_eliminates_dupes
    fields = Searchable.fields_for Person, :sections => "name,name,born_at"
    assert_equal ["name", "born_at"].sort, fields.sort
  end
  
  def test_fields_for_allows_dot_notation
    fields = Searchable.fields_for Person, :sections => "name.first,born_at,ssn.section1.prefix"
    assert_equal ["name.first", "born_at", "ssn.section1.prefix"].sort, fields.sort
  end
  
  def test_order_for_defaults_to_score_desc
    assert_equal([{"_score" => "desc"}], Searchable.order_for(Person, {}))
    assert_equal([{"_score" => "desc"}], Searchable.order_for(Person, {:order => ""}))
    assert_equal([{"_score" => "desc"}], Searchable.order_for(Person, {:order => nil}))
  end
  
  def test_order_for_uses_sort_and_order_params
    assert_equal([{"anything" => "desc"}], Searchable.order_for(Person, {:order => "anything"}))
    assert_equal([{"anything" => "desc"}], Searchable.order_for(Person, {:order => "anything", :sort => "desc"}))
    assert_equal([{"anything" => "asc"}], Searchable.order_for(Person, {:order => "anything", :sort => "asc"}))
    assert_equal([{"anything.else" => "asc"}], Searchable.order_for(Person, {:order => "anything.else", :sort => "asc"}))
  end
  
  def test_order_for_enforces_asc_or_desc
    assert_equal([{"anything" => "desc"}], Searchable.order_for(Person, {:order => "anything", :sort => "asdfkjashdf"}))
    assert_equal([{"anything" => "asc"}], Searchable.order_for(Person, {:order => "anything", :sort => "ASC"}))
    assert_equal([{"anything" => "desc"}], Searchable.order_for(Person, {:order => "anything", :sort => "ASCII"}))
  end
  
  def test_order_for_can_sort_score_in_desc
    assert_equal([{"_score" => "asc"}], Searchable.order_for(Person, {:order => "_score", :sort => "asc"}))
  end
end