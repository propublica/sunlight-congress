#!/usr/bin/env ruby

require 'test/unit'
require 'rubygems'
require 'bundler/setup'

require File.join ".", File.dirname(__FILE__), "../config/environment"
require File.join ".", File.dirname(__FILE__), "../searchable"


class SearchableTest < Test::Unit::TestCase
  
  class Person
    include Searchable::Model
    
    result_fields :name, :born_at, :ssn
    searchable_fields :name, :bio, :personal
    
    field_type :prisoner_id, String # override a number to be a string


    # for citation logic, which requires it also be queryable
    include Queryable::Model
    cite_key :ssn
  end

  class Animal
    include Searchable::Model

    result_fields :name, :born_at, :tag
    searchable_fields :name, :diary
  end
  
  # represents an ElasticSearch Hit object
  class FakeHit
    # float, doc score
    attr_accessor :_score, :_type
    
    # hash with keys that are fields and values that are arrays of highlighted text
    attr_accessor :highlight
    
    # hash where each key is a requested field name prefaced by
    attr_accessor :fields
    
    def self.default_score; 1.0; end
    def self.default_type; "fake_hit"; end
    
    def initialize(options = nil)
      # default values
      self._score = FakeHit.default_score
      self._type = FakeHit.default_type
      self.highlight = nil
      
      if options
        self._score = options[:_score] if options[:_score]
        self._type = options[:_type] if options[:_type]
        self.highlight = options[:highlight] if options[:highlight]
        self.fields = options[:fields] if options[:fields]
      end
    end
  end
  
  
  # partial responses
  
  def test_fields_for_returns_result_fields_if_sections_is_blank
    fields = Person.result_fields.map &:to_s
    assert_equal fields.sort, Searchable.fields_for(Person, {fields: ""}).sort
    assert_equal fields.sort, Searchable.fields_for(Person, {fields: nil}).sort
    assert_equal fields.sort, Searchable.fields_for(Person, {}).sort
    assert_equal ["name", "born_at", "ssn", "tag"].sort, Searchable.fields_for([Person, Animal], {}).sort
    assert_equal ["name", "ssn", "tag"].sort, Searchable.fields_for([Person, Animal], {fields: "name,ssn,tag"}).sort
  end
  
  def test_fields_for_allows_fields_outside_result_fields
    fields = Searchable.fields_for Person, fields: "name,born_at,sox"
    assert_equal ['name', 'born_at', 'sox'].sort, fields.sort
    
    # also make sure 'basic' is ignored, has no special meaning here
    fields = Searchable.fields_for Person, fields: "basic,name"
    assert_equal ["name", "basic"].sort, fields.sort
  end
   
  def test_fields_for_splits_on_a_comma
    fields = Searchable.fields_for Person, fields: "name,born_at,anything"
    assert_equal ['name', 'born_at', 'anything'].sort, fields.sort
  end
   
  def test_fields_for_eliminates_dupes
    fields = Searchable.fields_for Person, fields: "name,name,born_at"
    assert_equal ["name", "born_at"].sort, fields.sort
  end
  
  def test_fields_for_allows_dot_notation
    fields = Searchable.fields_for Person, fields: "name.first,born_at,ssn.section1.prefix"
    assert_equal ["name.first", "born_at", "ssn.section1.prefix"].sort, fields.sort
  end
  
  def test_fields_for_insists_on_cite_key_if_cite_param_is_present
    params = {fields: "name,whatever", citation_details: true, citation: "communism"}
    fields = Searchable.fields_for Person, params
    assert_equal ["name", "whatever", "ssn"].sort, fields.sort
  end

  def test_fields_for_doesnt_insert_duplicate_cite_key
    params = {fields: "name,whatever,ssn", citation_details: true, citation: "communism"}
    fields = Searchable.fields_for Person, params
    assert_equal ["name", "whatever", "ssn"].sort, fields.sort
  end
  
  # ordering
  
  def test_order_for_defaults_to_score_desc
    assert_equal([{"_score" => "desc"}], Searchable.order_for({}))
    assert_equal([{"_score" => "desc"}], Searchable.order_for({:order => ""}))
    assert_equal([{"_score" => "desc"}], Searchable.order_for({:order => nil}))
  end
  
  def test_order_for_uses_sort_and_order_params
    assert_equal([{"anything" => "desc"}], Searchable.order_for({:order => "anything"}))
    assert_equal([{"anything" => "desc"}], Searchable.order_for({:order => "anything", :sort => "desc"}))
    assert_equal([{"anything" => "asc"}], Searchable.order_for({:order => "anything", :sort => "asc"}))
    assert_equal([{"anything.else" => "asc"}], Searchable.order_for({:order => "anything.else", :sort => "asc"}))
  end
  
  def test_order_for_enforces_asc_or_desc
    assert_equal([{"anything" => "desc"}], Searchable.order_for({:order => "anything", :sort => "asdfkjashdf"}))
    assert_equal([{"anything" => "asc"}], Searchable.order_for({:order => "anything", :sort => "ASC"}))
    assert_equal([{"anything" => "desc"}], Searchable.order_for({:order => "anything", :sort => "ASCII"}))
  end
  
  def test_order_for_can_sort_score_in_asc
    assert_equal([{"_score" => "asc"}], Searchable.order_for({:order => "_score", :sort => "asc"}))
  end
  
  
  # specifying which fields to search with the query
  
  def test_search_fields_for_parses_search_parameter
    assert_equal ["name", "bio"].sort, Searchable.search_fields_for(Person, {search: "name,bio"}).sort
  end
  
  def test_search_fields_for_excludes_unspecified_fields
    assert_equal ["name"].sort, Searchable.search_fields_for(Person, {search: "name,ssn,born"}).sort
    assert_equal ["name", "bio"].sort, Searchable.search_fields_for(Person, {search: "name,ssn,bio"}).sort
  end
  
  def test_search_fields_for_removes_duplicates
    assert_equal ["name", "bio"].sort, Searchable.search_fields_for(Person, {search: "name,name,bio"}).sort
    assert_equal ["name"].sort, Searchable.search_fields_for(Person, {search: "name,name"}).sort
  end
  
  def test_search_fields_defaults_to_all_fields
    assert_equal ["name", "bio", "personal"].sort, Searchable.search_fields_for(Person, {search: ""}).sort
    assert_equal ["name", "bio", "personal"].sort, Searchable.search_fields_for(Person, {search: nil}).sort
    assert_equal ["name", "bio", "personal"].sort, Searchable.search_fields_for(Person, {}).sort
  end

  def test_search_fields_multiple_models
    assert_equal ["name", "bio", "personal", "diary"].sort, Searchable.search_fields_for([Person, Animal], {}).sort
    assert_equal ["bio", "diary"].sort, Searchable.search_fields_for([Animal, Person], {search: "bio,diary"}).sort
  end
  
  
  # querying
  
  def test_term_for_strips
    assert_equal "whatever", Searchable.term_for({:query => "  \nwhatever\t"})
  end
  
  def test_term_for_downcases
    assert_equal "whatever", Searchable.term_for({:query => "WHAteveR"})
  end
  
  
  # filtering
  
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
    assert !Searchable.magic_fields.include?(field)
    
    filter = Searchable.filter_for Person, {"hands" => "two", Searchable.magic_fields.first => "anything"}
    assert_equal Searchable.subfilter_for("hands", "two"), filter
  end
  
  def test_filter_for_with_no_valid_filters_yields_nil
    assert_nil Searchable.filter_for(Person, {})
    assert_nil Searchable.filter_for(Person, {Searchable.magic_fields.first => "anything"})
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
  
  # should act like dates, until we support ranges
  def test_subfilter_for_times
    field = "born_at"
    value = "2011-05-06T07:00:00Z"
    parsed_value = Searchable.value_for value, nil
    from = Time.zone.parse(value).midnight.utc
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
    
    assert_equal filter, Searchable.subfilter_for(field, parsed_value)
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
  
  
  # attributes post-processing (transforming ElasticSearch responses into our responses)
  
  def test_attributes_for_retrieves_fields_from_hit
    term = "anything"
    hit = FakeHit.new(
      :fields => {
                  "bill_version_id" => "s627-112-rs",
                  "version_code" => "rs"
                 }
    )
    model = Person
    fields = ["bill_version_id", "version_code"]
    
    attributes = {
      :search => {
                  :score => FakeHit.default_score,
                  :query => term,
                  :type => FakeHit.default_type
                 },
      'bill_version_id' => "s627-112-rs",
      'version_code' => "rs"
    }
    
    assert_equal attributes, Searchable.attributes_for(term, hit, fields)
  end
  
  def test_attributes_for_retrieves_score_from_hit
    term = "anything"
    hit = FakeHit.new(
      :fields => {
                  "bill_version_id" => "s627-112-rs",
                  "version_code" => "rs"
                 },
      :_score => 2.0
    )
    model = Person
    fields = ["bill_version_id", "version_code"]
    
    attributes = {
      :search => {
                  :score => 2.0,
                  :query => term,
                  :type => FakeHit.default_type
                 },
      'bill_version_id' => "s627-112-rs",
      'version_code' => "rs"
    }
    
    assert_equal attributes, Searchable.attributes_for(term, hit, fields)
  end
  
  def test_attributes_for_retrieves_highlight_from_hit
    highlight = {
      "full_text" => ["whatever", "whatever also"],
      "bill.summary" => ["dot notation stays"]
    }
    
    term = "anything"
    hit = FakeHit.new(
      :fields => {
                  "bill_version_id" => "s627-112-rs",
                  "version_code" => "rs"
                 },
      :highlight => highlight
    )
    model = Person
    fields = ["bill_version_id", "version_code"]
    
    attributes = {
      :search => {
                  :score => FakeHit.default_score,
                  :query => term,
                  :type => FakeHit.default_type,
                  :highlight => highlight
                 },
      'bill_version_id' => "s627-112-rs",
      'version_code' => "rs"
    }
    
    assert_equal attributes, Searchable.attributes_for(term, hit, fields)
  end
  
  def test_attributes_for_unwraps_dot_notation_in_fields
    term = "anything"
    hit = FakeHit.new(
      :fields => {
                  "bill.bill_id" => "s627-112",
                  "bill.last_action.text" => "did stuff"
                 }
    )
    model = Person
    fields = ["bill.bill_id", "bill.last_action.text"]
    
    attributes = {
      :search => {
                  :score => FakeHit.default_score,
                  :query => term,
                  :type => FakeHit.default_type
                 },
      'bill' => {
                 'bill_id' => 's627-112',
                 'last_action' => {
                      'text' => "did stuff"
                    }
                 }
    }
    
    assert_equal attributes, Searchable.attributes_for(term, hit, fields)
  end
  
end