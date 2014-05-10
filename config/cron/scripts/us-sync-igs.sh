#!/bin/bash

cd $HOME/unitedstates/inspectors-general
source $HOME/.virtualenvs/inspectors/bin/activate

# get latest IG reports from all 'safe' scrapers
./igs --safe > $HOME/congress/shared/cron/output/us-sync-igs.txt 2>&1
