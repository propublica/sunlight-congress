#!/usr/bin/env ruby

require 'test/unit'
require 'rubygems'
require 'bundler/setup'

require File.join ".", File.dirname(__FILE__), "../config/environment"
require File.join ".", File.dirname(__FILE__), "../queryable"


class QueryableTest < Test::Unit::TestCase
  
  class Person
    include Queryable::Model
    
    basic_fields :name, :bio, :born_at
    
    default_order :born_at
    
    search_fields :name, :bio

    cite_key :ssn
    
    # not actually persisted anywhere, just want the model behavior
    include Mongoid::Document
    include Mongoid::Timestamps
  end
  
  def test_fields_for_returns_nil_if_sections_is_blank
    assert_nil Queryable.fields_for Person, {:sections => ""}
    assert_nil Queryable.fields_for Person, {:sections => nil}
    assert_nil Queryable.fields_for Person, {}
  end
  
  def test_fields_for_splits_on_a_comma
    fields = Queryable.fields_for Person, fields: "name,whatever,sox"
    assert_equal ['name', 'whatever', 'sox'].sort, fields.sort
  end
  
  def test_fields_for_breaks_out_basic_fields
    fields = Queryable.fields_for Person, fields: "basic,whatever,sox"
    assert_equal ["name", "bio", "born_at", "whatever", "sox"].sort, fields.sort
  end
  
  def test_fields_for_eliminates_dupes
    fields = Queryable.fields_for Person, fields: "basic,name,name,sox,bio"
    assert_equal ["name", "bio", "born_at", "sox"].sort, fields.sort
  end

  def test_fields_for_insists_on_cite_key_if_cite_param_is_present
    params = {fields: "name,whatever", citation_details: true, citation: "communism"}
    fields = Queryable.fields_for Person, params
    assert_equal ["name", "whatever", "ssn"].sort, fields.sort
  end

  def test_conditions_for_produces_simple_hash
    conditions = Queryable.conditions_for Person, chamber: "senate"
    assert_equal({chamber: "senate"}, conditions)
  end

  def test_conditions_for_inserts_citation_filter_if_requested
    conditions = Queryable.conditions_for Person, chamber: "senate", citation: "098"
    assert_equal({chamber: "senate", "citation_ids" => "098"}, conditions)
  end

  
end