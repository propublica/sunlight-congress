#!/bin/bash

cd $HOME/unitedstates/congress
source $HOME/.virtualenvs/us-congress/bin/activate

# get all nominations in the current congress, re-download everything
./run nominations --force > $HOME/congress/shared/cron/output/us-sync-nominations.txt 2>&1

