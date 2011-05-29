#!/usr/bin/env ruby

require 'test/unit'
require 'rubygems'
require 'bundler/setup'

require File.join File.dirname(__FILE__), "../config/environment"
require File.join File.dirname(__FILE__), "../queryable"


class QueryableTest < Test::Unit::TestCase
  
  class Person
    include Queryable::Model
    
    basic_fields :name, :bio, :born_at
    
    default_order :born_at
    
    search_fields :name, :bio
    
    # not actually persisted anywhere, just want the model behavior
    include Mongoid::Document
    include Mongoid::Timestamps
  end
  
  def test_fields_for_returns_nil_if_sections_is_blank
    assert_nil Queryable.fields_for Person, {:sections => ""}
    assert_nil Queryable.fields_for Person, {:sections => nil}
    assert_nil Queryable.fields_for Person, {}
  end
  
end