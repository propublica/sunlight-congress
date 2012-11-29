#!/usr/bin/env ruby

require 'test/unit'
require 'rubygems'
require 'bundler/setup'

require File.join ".", File.dirname(__FILE__), "../config/environment"
require File.join ".", File.dirname(__FILE__), "../searchable"


class SearchableTest < Test::Unit::TestCase
  
  class Person
    include Api::Model
    
    basic_fields :name, :born_at, :ssn
    search_fields :name, :bio, :personal
    cite_key :ssn
  end

  def test_filter_for_parses_filters_into_anded_subfilters
    filter = Searchable.filter_for Person, {'favorite_drug' => "opium", 'fingers' => "9"}
    
    assert_not_nil filter[:and]
    assert filter[:and].is_a?(Hash)
    assert_not_nil filter[:and][:filters]
    assert filter[:and][:filters].is_a?(Array)
    
    assert filter[:and][:filters].include?(Searchable.subfilter_for('favorite_drug', 'opium'))
    assert filter[:and][:filters].include?(Searchable.subfilter_for('fingers', 9))
  end

  def test_filter_for_includes_citation
    filter = Searchable.filter_for Person, {'favorite_drug' => "opium", 'fingers' => "9", :citation => "communism"}
    
    assert_not_nil filter[:and]
    assert filter[:and].is_a?(Hash)
    assert_not_nil filter[:and][:filters]
    assert filter[:and][:filters].is_a?(Array)
    
    assert filter[:and][:filters].include?(Searchable.subfilter_for('favorite_drug', 'opium'))
    assert filter[:and][:filters].include?(Searchable.subfilter_for('fingers', 9))

    citation_filter = Searchable.citation_filter_for('citation_ids', 'communism')
    assert filter[:and][:filters].include?(citation_filter), filter[:and][:filters].inspect
  end

  def test_filter_for_with_only_citation
    filter = Searchable.filter_for Person, {citation: "communism"}
    assert_equal filter, Searchable.citation_filter_for('citation_ids', 'communism')
  end
  
  def test_filter_for_allows_subfields_in_filters
    # one subfilter is left alone
    filter = Searchable.filter_for Person, {'fingers.left' => "9"}
    assert_equal Searchable.subfilter_for("fingers.left", 9), filter

    # more than one are 'and'-ed together
    filter = Searchable.filter_for Person, {'fingers.left' => "9", 'fingers.right' => "10"}
    assert_equal Searchable.subfilter_for("fingers.left", 9), filter[:and][:filters][0]
    assert_equal Searchable.subfilter_for("fingers.right", 10), filter[:and][:filters][1]
  end
  
  def test_filter_for_ignores_magic_fields_in_filters
    field = "hands"
    assert !Api.magic_fields.include?(field)
    
    filter = Searchable.filter_for Person, {"hands" => "two", Api.magic_fields.first => "anything"}
    assert_equal Searchable.subfilter_for("hands", "two"), filter
  end
  
  def test_filter_for_with_no_valid_filters_yields_nil
    assert_nil Searchable.filter_for(Person, {})
    assert_nil Searchable.filter_for(Person, {Api.magic_fields.first => "anything"})
    assert_nil Searchable.filter_for(Person, {whatev: ""})
  end
  
  def test_subfilter_for_strings
    field = "water"
    value = "good"
    filter = {
      :query => {
        :text => {
          field => {
            :query => value,
            :type => "phrase"
          }
        }
      }
    }
    
    assert_equal filter, Searchable.subfilter_for(field, value)
  end

  def test_subfilter_for_integers
    field = "fingers"
    value = "9" # it will start out as a string in the params
    
    filter = {
      :term => {
        field.to_s => value
      }
    }
    
    assert_equal filter, Searchable.subfilter_for(field, 9)
  end
  
  def test_subfilter_for_integer_ranges
    field = "fingers"
    operator = "gt"
    value = "9" # it will start out as a string in the params
    
    filter = {
      :range => {
        field.to_s => {
          'gt' => value
        }
      }
    }
    
    assert_equal filter, Searchable.subfilter_for(field, 9, "gt")
  end
  
  def test_subfilter_for_booleans
    field = "right_handed"
    value = "true"
    
    filter = {
      :term => {
        field.to_s => value
      }
    }
    
    assert_equal filter, Searchable.subfilter_for(field, true)
  end
  
  def test_subfilter_for_dates
    field = "born_at"
    value = "2011-05-06"
    from = Time.zone.parse(value).utc
    
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
    
    assert_equal filter, Searchable.subfilter_for(field, from)
  end
  
  
  def test_subfilter_for_allows_override_of_type
    field = "prisoner_id"
    value = "1"
    filter = {
      :query => {
        :text => {
          field => {
            :query => value,
            :type => "phrase"
          }
        }
      }
    }
    
    assert_equal filter, Searchable.subfilter_for(field, value)
  end
end