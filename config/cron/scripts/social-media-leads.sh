#!/bin/bash

cd $HOME/unitedstates/congress-legislators
git pull origin master

cd $HOME/unitedstates/congress-legislators/scripts
source $HOME/.virtualenvs/us-congress-legislators/bin/activate

# sweep legislator websites for social media leads, email
./social_media.py --sweep --service=twitter --email > $HOME/congress/shared/cron/output/social-media-leads.txt 2>&1
./social_media.py --sweep --service=facebook --email > $HOME/congress/shared/cron/output/social-media-leads.txt 2>&1
./social_media.py --sweep --service=youtube --email > $HOME/congress/shared/cron/output/social-media-leads.txt 2>&1

