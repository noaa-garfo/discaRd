#!/bin/bash

# GET TIMESTAMP
start_time=$(date +%Y-%m-%d_%H%M)

# GET EXECUTION DIR
exec_dir=$(pwd)


# ASK FOR MAPS PASSWORD
echo -n Enter MAPS Password:
read -s password
echo

# ASK FOR OBDBS YEAR TO UPDATE
echo -n Enter OBDBS Year in YYYY to update:
read year
echo

# RUN OBDBS UPDATE SCRIPT
set verify off
set autotrace traceonly
set SERVEROUTPUT OFF
set termout off
echo exit | nohup sqlplus -S maps/$password@NERO.WORLD  @"test_make_obdbs_top.sql" $year > /dev/null

echo
echo OBDBS UPDATE $year END:
echo $(date)
echo