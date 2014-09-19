#!/bin/bash

cd $HOME/unitedstates/congress
source $HOME/.virtualenvs/us-congress/bin/activate

# get all bills in the current session, re-download everything
./run bills --force > $HOME/congress/shared/log/cron/us-sync-bills-all.txt 2>&1

