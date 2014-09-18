#!/bin/bash

cd $HOME/unitedstates/congress
source $HOME/.virtualenvs/us-congress/bin/activate

# get all upcomming bills on the House Floor for the week
./run upcoming_house_floor  > $HOME/congress/shared/cron/output/upcoming-house-floor.txt 2>&1

# now switch to congress 
. $HOME/.bashrc 
source $HOME/.virtualenvs/congress/bin/activate
cd $HOME/congress/current

# load data from scraper into the api
rake task:upcoming_house
