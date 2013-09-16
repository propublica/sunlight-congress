#!/bin/bash

. $HOME/.bashrc
cd $HOME/congress/current
rake analytics:report >> $HOME/congress/shared/cron/output/analytics.txt 2>&1
