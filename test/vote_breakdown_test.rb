#!/usr/bin/env ruby

require 'test/unit'
require 'rubygems'
require 'bundler/setup'

require File.join(File.dirname(__FILE__), "../config/environment")
require File.join(File.dirname(__FILE__), "../tasks/utils")

class VoteBreakdownTest < Test::Unit::TestCase
  
  def test_vote_breakdown_for_regular_vote
    voters = {
        'a' => {:voter => {'party' => 'R'}, :vote => 'Yea'},
        'b' => {:voter => {'party' => 'R'}, :vote => 'Yea'},
        'c' => {:voter => {'party' => 'R'}, :vote => 'Not Voting'},
        'd' => {:voter => {'party' => 'D'}, :vote => 'Nay'},
        'e' => {:voter => {'party' => 'D'}, :vote => 'Yea'},
      }
    breakdown = Utils.vote_breakdown_for voters
    totals = breakdown.delete :total
    
    assert_equal 1, totals['Not Voting']
    assert_equal 3, totals['Yea']
    assert_equal 1, totals['Nay']
    assert_not_nil totals['Present']
    assert_equal 0, totals['Present']
    
    assert_equal 2, breakdown['R']['Yea']
    assert_equal 1, breakdown['R']['Not Voting']
    assert_not_nil breakdown['R']['Present']
    assert_equal 0, breakdown['R']['Present']
    assert_not_nil breakdown['R']['Nay']
    assert_equal 0, breakdown['R']['Nay']
    
    assert_equal 1, breakdown['D']['Yea']
    assert_equal 1, breakdown['D']['Nay']
    assert_not_nil breakdown['D']['Present']
    assert_equal 0, breakdown['D']['Present']
    assert_not_nil breakdown['D']['Not Voting']
    assert_equal 0, breakdown['D']['Not Voting']
  end
  
  def test_vote_breakdown_for_speaker_election
    voters = {
        'a' => {:voter => {'party' => 'R'}, :vote => 'Boehner'},
        'b' => {:voter => {'party' => 'R'}, :vote => 'Boehner'},
        'c' => {:voter => {'party' => 'R'}, :vote => 'Pelosi'},
        'd' => {:voter => {'party' => 'D'}, :vote => 'Pelosi'},
        'e' => {:voter => {'party' => 'D'}, :vote => 'Pelosi'},
      }
    
    breakdown = Utils.vote_breakdown_for voters
    totals = breakdown.delete :total
    
    assert_equal 3, totals['Pelosi']
    assert_equal 2, totals['Boehner']
    Utils.constant_vote_keys.each do |vote|
      assert_not_nil totals[vote]
      assert_equal 0, totals[vote]
    end
    
    assert_equal 2, breakdown['D']['Pelosi']
    assert_not_nil breakdown['D']['Boehner']
    assert_equal 0, breakdown['D']['Boehner']
    assert_equal 2, breakdown['R']['Boehner']
    assert_equal 1, breakdown['R']['Pelosi']
    
    Utils.constant_vote_keys.each do |vote|
      assert_not_nil breakdown['D'][vote]
      assert_equal 0, breakdown['D'][vote]
      assert_not_nil breakdown['R'][vote]
      assert_equal 0, breakdown['R'][vote]
    end
  end
  
end