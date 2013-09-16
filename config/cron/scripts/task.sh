#!/bin/bash

. $HOME/.bashrc 
source $HOME/.virtualenvs/congress/bin/activate
cd $HOME/congress/current 

FIRST=$1
shift
rake task:$FIRST $@ > $HOME/congress/shared/cron/output/$FIRST.txt 2>&1

