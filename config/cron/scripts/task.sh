#!/bin/bash

. $HOME/.bashrc 
source $HOME/.virtualenvs/congress/bin/activate
cd $HOME/congress/current 

FIRST=$1

lockfile -r 10 $HOME/tmp/locks/$FIRST.lock

shift
rake task:$FIRST $@ > $HOME/congress/shared/cron/output/$FIRST.txt 2>&1

rm -f $HOME/tmp/locks/$FIRST.lock