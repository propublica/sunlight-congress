#!/bin/bash

cd $HOME/unitedstates/us-sync
source $HOME/.virtualenvs/us-sync/bin/activate

# sync the current congress up to S3 each night
./sync --congresses=113 > $HOME/congress/shared/log/cron/unitedstates-s3.txt 2>&1

