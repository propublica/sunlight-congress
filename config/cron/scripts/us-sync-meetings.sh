#!/bin/bash

cd $HOME/unitedstates/congress
source $HOME/.virtualenvs/us-congress/bin/activate

# get all committee meetings in the current session, re-download everything
./run committee_meetings > $HOME/congress/shared/log/cron/us-sync-meetings.txt 2>&1

