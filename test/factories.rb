require 'factory_girl'

FactoryGirl.define do

  factory :api_key do
    sequence(key) {|n| "development-#{n}"}
    sequence(email) {|n| "test-#{n}@example.com"}
    status "A"
  end

  factory :legislator do
    first_name "Louis"
    last_name "Brandeis"
    bioguide "B001122"
  end

end