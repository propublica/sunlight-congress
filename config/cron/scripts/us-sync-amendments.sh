#!/bin/bash

cd $HOME/unitedstates/congress
source $HOME/.virtualenvs/us-congress/bin/activate

# get all amendments in the current session, re-download everything
./run amendments --fast --force > $HOME/congress/shared/cron/output/us-sync-amendments.txt 2>&1

