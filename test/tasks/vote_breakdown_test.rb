#!/usr/bin/env ruby

require 'test/unit'
require 'rubygems'
require 'bundler/setup'

require File.join(File.dirname(__FILE__), "../../config/environment")
require File.join(File.dirname(__FILE__), "../../tasks/utils")

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
    party = breakdown.delete :party
    
    assert_equal 1, totals['Not Voting']
    assert_equal 3, totals['Yea']
    assert_equal 1, totals['Nay']
    assert_not_nil totals['Present']
    assert_equal 0, totals['Present']
    
    assert_equal 2, party['R']['Yea']
    assert_equal 1, party['R']['Not Voting']
    assert_not_nil party['R']['Present']
    assert_equal 0, party['R']['Present']
    assert_not_nil party['R']['Nay']
    assert_equal 0, party['R']['Nay']
    
    assert_equal 1, party['D']['Yea']
    assert_equal 1, party['D']['Nay']
    assert_not_nil party['D']['Present']
    assert_equal 0, party['D']['Present']
    assert_not_nil party['D']['Not Voting']
    assert_equal 0, party['D']['Not Voting']
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
    party = breakdown.delete :party
    
    assert_equal 3, totals['Pelosi']
    assert_equal 2, totals['Boehner']
    Utils.constant_vote_keys.each do |vote|
      assert_not_nil totals[vote]
      assert_equal 0, totals[vote]
    end
    
    assert_equal 2, party['D']['Pelosi']
    assert_not_nil party['D']['Boehner']
    assert_equal 0, party['D']['Boehner']
    assert_equal 2, party['R']['Boehner']
    assert_equal 1, party['R']['Pelosi']
    
    Utils.constant_vote_keys.each do |vote|
      assert_not_nil party['D'][vote]
      assert_equal 0, party['D'][vote]
      assert_not_nil party['R'][vote]
      assert_equal 0, party['R'][vote]
    end
  end

  def test_voter_ids_for_search_indexing
    voter_ids = {
      'a' => 'Nay',
      'b' => 'Yea',
      'c' => 'Yea',
      'd' => 'Not Voting',
      'e' => 'Pelosi'
    }

    # should have all the keys that appeared, plus the constants

    new_voter_ids = Utils.search_voter_ids voter_ids

    voter_ids.values.uniq.each do |vote|
      assert_not_nil new_voter_ids[vote]
    end

    voter_ids.keys.uniq.each do |id|
      value = voter_ids[id]
      assert new_voter_ids[value].include?(id)
    end

    assert_equal voter_ids.keys.size, voter_ids.values.flatten.size

  end
  
end