#!/bin/bash

cd $HOME/unitedstates/congress
source $HOME/.virtualenvs/us-congress/bin/activate

# get all bills in the current session, re-download everything
./run bills --fast --force > $HOME/congress/shared/cron/output/us-sync-bills.txt 2>&1

