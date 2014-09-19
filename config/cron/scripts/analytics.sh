#!/bin/bash

. $HOME/.bashrc
cd $HOME/congress/current
rake analytics:report >> $HOME/congress/shared/log/cron/analytics.txt 2>&1
