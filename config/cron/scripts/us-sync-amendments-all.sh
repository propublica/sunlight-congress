#!/bin/bash

cd $HOME/unitedstates/congress
source $HOME/.virtualenvs/us-congress/bin/activate

# get all amendments in the current session, re-download everything
./run amendments --force > $HOME/congress/shared/log/cron/us-sync-amendments-all.txt 2>&1

