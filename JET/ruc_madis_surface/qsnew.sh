#!/bin/sh --login
# get login environment, which is needed by qsub
#echo "I was called with $# parameters"
#echo "My name is $0"
#echo "My first parameter is $1"
#echo "My second parameter is $2"
#echo "All parameters are $@"
#echo "path is " `dirname $1`
#source .cshrc
cd `dirname $1`
echo "qsub $1 -F \"$2 $3 $4 $5 $6 $7 $8 $9\"" 
qsub $1 -F "$2 $3 $4 $5 $6 $7 $8 $9" 
exit;

