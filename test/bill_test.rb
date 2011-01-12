#!/usr/bin/env ruby

require 'test/unit'
require 'rubygems'
require 'bundler/setup'

require File.join File.dirname(__FILE__), "../config/environment"
require File.join File.dirname(__FILE__), "../tasks/utils"
require File.join File.dirname(__FILE__), "../tasks/bills_archive/bills_archive"

class BillTest < Test::Unit::TestCase
  
  def test_title_extraction
    cases = {
      'hr1-stimulus' => {
         :short => "American Recovery and Reinvestment Act of 2009",
         :official => "Making supplemental appropriations for job preservation and creation, infrastructure investment, energy efficiency and science, assistance to the unemployed, and State and local fiscal stabilization, for fiscal year ending September 30, 2009, and for other purposes."
      },
      'hr3590-health-care' => {
         :short => "Patient Protection and Affordable Care Act",
         :official => "An act entitled The Patient Protection and Affordable Care Act."
      },
      'hr4173-wall-street' => {
         :short => "Wall Street Reform and Consumer Protection Act of 2009",
         :official => "To provide for financial regulatory reform, to protect consumers and investors, to enhance Federal understanding of insurance issues, to regulate the over-the-counter derivatives markets, and for other purposes."
      },
      'no-short' => {
         :short => nil,
         :official => "An act entitled The Patient Protection and Affordable Care Act."
      }
    }
    
    cases.each do |filename, recents|
      doc = Nokogiri::XML open(fixture("titles/#{filename}.xml"))
      titles = BillsArchive.titles_for doc
      assert_equal recents[:short], BillsArchive.most_recent_title_from(titles, :short)
      assert_equal recents[:official], BillsArchive.most_recent_title_from(titles, :official)
    end
  end
  
  def test_timeline_construction
    cases = {
      :introduced => {
        :house_passage_result => :missing,
        :house_passage_result_at => :missing, 
        :senate_passage_result => :missing,
        :senate_passage_result_at => :missing, 
        :enacted => false,
        :enacted_at => :missing,  
        :vetoed => false,
        :vetoed_at => :missing,
        :house_override_result => :missing,
        :house_override_result_at => :missing, 
        :senate_override_result => :missing, 
        :senate_override_result_at => :missing,
        :awaiting_signature => false,
        :awaiting_signature_since => :missing
      },
      :enacted_normal => {
        :house_passage_result => 'pass',
        :house_passage_result_at => :not_null, 
        :senate_passage_result => 'pass',
        :senate_passage_result_at => :not_null, 
        :enacted => true,
        :enacted_at => :not_null,
        :vetoed => false,
        :vetoed_at => :missing,
        :house_override_result => :missing,
        :house_override_result_at => :missing, 
        :senate_override_result => :missing, 
        :senate_override_result_at => :missing,
        :awaiting_signature => false,
        :awaiting_signature_since => :missing
      },
      :veto_override_failed => {
        :house_passage_result => 'pass',
        :house_passage_result_at => :not_null, 
        :senate_passage_result => 'pass',
        :senate_passage_result_at => :not_null, 
        :enacted => false,
        :enacted_at => :missing,
        :vetoed => true,
        :vetoed_at => :not_null,
        :house_override_result => 'fail',
        :house_override_result_at => :not_null, 
        :senate_override_result => :missing, 
        :senate_override_result_at => :missing,
        :awaiting_signature => false,
        :awaiting_signature_since => :missing
      },
      :veto_override_passed => {
        :house_passage_result => 'pass',
        :house_passage_result_at => :not_null, 
        :senate_passage_result => 'pass',
        :senate_passage_result_at => :not_null, 
        :enacted => true,
        :enacted_at => :not_null,
        :vetoed => true,
        :vetoed_at => :not_null,
        :house_override_result => 'pass',
        :house_override_result_at => :not_null, 
        :senate_override_result => 'pass', 
        :senate_override_result_at => :not_null,
        :awaiting_signature => false,
        :awaiting_signature_since => :missing
      },
      :passed_house_only => {
        :house_passage_result => 'pass',
        :house_passage_result_at => :not_null, 
        :senate_passage_result => :missing,
        :senate_passage_result_at => :missing, 
        :enacted => false,
        :enacted_at => :missing,
        :vetoed => false,
        :vetoed_at => :missing,
        :house_override_result => :missing,
        :house_override_result_at => :missing, 
        :senate_override_result => :missing, 
        :senate_override_result_at => :missing,
        :awaiting_signature => false,
        :awaiting_signature_since => :missing
      },
      :enacted_but_one_vote => {
        :house_passage_result => :missing,
        :house_passage_result_at => :missing, 
        :senate_passage_result => 'pass',
        :senate_passage_result_at => :not_null, 
        :enacted => true,
        :enacted_at => :not_null,
        :vetoed => false,
        :vetoed_at => :missing,
        :house_override_result => :missing,
        :house_override_result_at => :missing, 
        :senate_override_result => :missing, 
        :senate_override_result_at => :missing,
        :awaiting_signature => false,
        :awaiting_signature_since => :missing
      },
      :passed_awaiting_signature => {
        :house_passage_result => 'pass',
        :house_passage_result_at => :not_null, 
        :senate_passage_result => 'pass',
        :senate_passage_result_at => :not_null, 
        :enacted => false,
        :enacted_at => :missing,
        :vetoed => false,
        :vetoed_at => :missing,
        :house_override_result => :missing,
        :house_override_result_at => :missing, 
        :senate_override_result => :missing, 
        :senate_override_result_at => :missing,
        :awaiting_signature => true,
        :awaiting_signature_since => :not_null
      },
      :passed_awaiting_conference => {
        :house_passage_result => 'pass',
        :house_passage_result_at => :not_null, 
        :senate_passage_result => 'pass',
        :senate_passage_result_at => :not_null, 
        :enacted => false,
        :enacted_at => :missing,
        :vetoed => false,
        :vetoed_at => :missing,
        :house_override_result => :missing,
        :house_override_result_at => :missing, 
        :senate_override_result => :missing, 
        :senate_override_result_at => :missing,
        :awaiting_signature => false,
        :awaiting_signature_since => :missing
      }
    }
    
    cases.keys.each do |name|
      doc = Nokogiri::XML open(fixture("timeline/#{name}.xml"))
      state = BillsArchive.state_for doc
      passage_votes = BillsArchive.passage_votes_for doc
      timeline = BillsArchive.timeline_for doc, state, passage_votes
      
      cases[name].each do |key, value|
        if value == :missing
          assert !timeline.key?(key), "[#{name}] #{key}: #{value}"
        elsif value == :not_null
          assert_not_nil timeline[key], "[#{name}] #{key}: #{value}"
        else
          assert_equal value, timeline[key], "[#{name}] #{key}: #{value}"
        end
      end
    end
    
  end
  
  def fixture(path)
    File.join File.dirname(__FILE__), "fixtures", path
  end
  
end