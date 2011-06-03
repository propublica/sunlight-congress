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
    searchable_fields :name, :bio, :personal
    
    field_type :prisoner_id, String # override a number to be a string
  end
  
  
  # partial responses
  
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
  
  
  # ordering
  
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
  
  
  # specifying which fields to search with the query
  
  def test_search_fields_for_parses_search_parameter
    assert_equal ["name", "bio"].sort, Searchable.search_fields_for(Person, {:search => "name,bio"}).sort
  end
  
  def test_search_fields_for_excludes_unspecified_fields
    assert_equal ["name"].sort, Searchable.search_fields_for(Person, {:search => "name,ssn,born"}).sort
    assert_equal ["name", "bio"].sort, Searchable.search_fields_for(Person, {:search => "name,ssn,bio"}).sort
  end
  
  def test_search_fields_for_removes_duplicates
    assert_equal ["name", "bio"].sort, Searchable.search_fields_for(Person, {:search => "name,name,bio"}).sort
    assert_equal ["name"].sort, Searchable.search_fields_for(Person, {:search => "name,name"}).sort
  end
  
  def test_search_fields_defaults_to_all_fields
    assert_equal ["name", "bio", "personal"].sort, Searchable.search_fields_for(Person, {:search => ""}).sort
    assert_equal ["name", "bio", "personal"].sort, Searchable.search_fields_for(Person, {:search => nil}).sort
    assert_equal ["name", "bio", "personal"].sort, Searchable.search_fields_for(Person, {}).sort
  end
  
  
  # querying
  
  def test_query_for_uses_dis_max_query
    conditions = Searchable.query_for Person, {:query => "sideburns"}, ['bio']
    assert_not_nil conditions[:dis_max]
    assert_not_nil conditions[:dis_max][:queries]
    assert conditions[:dis_max][:queries].is_a?(Array)
  end
  
  def test_query_for_incorporates_search_query
    search_fields = ['bio', 'name']
    term = "sideburns"
    
    query = Searchable.query_for Person, {:query => term}, search_fields
    subqueries = query[:dis_max][:queries]
    assert_equal 2, subqueries.size
    assert subqueries.include?(Searchable.subquery_for(term, 'bio')), "No bio subquery."
    assert subqueries.include?(Searchable.subquery_for(term, 'name')), "No name subquery."
  end
  
  
  # filtering
  
  def test_filter_for_parses_filters_into_anded_subfilters
    filter = Searchable.filter_for Person, {:favorite_drug => "opium", :fingers => "9"}
    
    assert_not_nil filter[:and]
    assert filter[:and].is_a?(Array)
    
    assert filter[:and].include?(Searchable.subfilter_for(Person, 'favorite_drug', 'opium'))
    assert filter[:and].include?(Searchable.subfilter_for(Person, 'fingers', "9"))
  end
  
  def test_filter_for_doesnt_know_about_operators
    filter = Searchable.filter_for Person, {:fingers__gt => "9"}
    assert_equal Searchable.subfilter_for(Person, "fingers__gt", "9"), filter[:and][0]
  end
  
  def test_filter_for_allows_subfields_in_filters
    filter = Searchable.filter_for Person, {'fingers.left' => "9"}
    assert_equal Searchable.subfilter_for(Person, "fingers.left", "9"), filter[:and][0]
  end
  
  def test_filter_for_ignores_magic_fields_in_filters
    field = "hands"
    assert !Searchable.magic_fields.include?(field)
    
    filter = Searchable.filter_for Person, {"hands" => "two", Searchable.magic_fields.first => "anything"}
    assert_equal 1, filter[:and].size
    assert_equal Searchable.subfilter_for(Person, "hands", "two"), filter[:and][0]
  end
  
  def test_filter_for_with_no_valid_filters_yields_nil
    assert_nil Searchable.filter_for(Person, {})
    assert_nil Searchable.filter_for(Person, {Searchable.magic_fields.first => "anything"})
    assert_nil Searchable.filter_for(Person, {:whatev => ""})
  end
  
  def test_subfilter_for_strings
    field = "water"
    value = "good"
    filter = {
      :query => {
        :query_string => {
          :fields => [field],
          :query => value
        }
      }
    }
    
    assert_equal filter, Searchable.subfilter_for(Person, field, value)
  end
  
  def test_subfilter_for_integers
    field = "fingers"
    value = "9" # it will start out as a string in the params
    
    filter = {
      :numeric_range => {
        field.to_s => {
          :from => value,
          :to => value
        }
      }
    }
    
    assert_equal filter, Searchable.subfilter_for(Person, field, value)
  end
  
  def test_subfilter_for_booleans
    field = "right_handed"
    value = "true"
    
    filter = {
      :term => {
        field.to_s => value
      }
    }
    
    assert_equal filter, Searchable.subfilter_for(Person, field, value)
  end
  
  def test_subfilter_for_dates
    field = "born_at"
    value = "2011-05-06"
    from = Time.parse value
    to = from + 1.day
    
    filter = {
      :range => {
        field.to_s => {
          :from => from.iso8601,
          :to => to.iso8601,
          :include_upper => false
        }
      }
    }
    
    assert_equal filter, Searchable.subfilter_for(Person, field, value)
  end
  
  # should act like dates, until we support ranges
  def test_subfilter_for_times
    field = "born_at"
    value = "2011-05-06T07:00:00Z"
    from = Time.parse(value).midnight
    to = from + 1.day
    
    filter = {
      :range => {
        field.to_s => {
          :from => from.iso8601,
          :to => to.iso8601,
          :include_upper => false
        }
      }
    }
    
    assert_equal filter, Searchable.subfilter_for(Person, field, value)
  end
  
  def test_subfilter_for_allows_override_of_type
    field = "prisoner_id"
    value = "1"
    filter = {
      :query => {
        :query_string => {
          :fields => [field],
          :query => value
        }
      }
    }
    
    assert_equal filter, Searchable.subfilter_for(Person, field, value)
  end
  
end