#!/bin/sh -login
# get login environment, which is needed by sbatch
#echo "I was called with $# parameters"
#echo "My name is $0"
#echo "My first parameter is $1"
#echo "My second parameter is $2"
#echo "All parameters are $@"
#echo "path is " `dirname $1`
#source .cshrc
#module load slurm

echo `dirname $1`
cd `dirname $1`
echo "sbatch $1 $2 $3 $4 $5 $6 $7 $8 $9" 
/apps/slurm/default/bin/sbatch $1 $2 $3 $4 $5 $6 $7 $8 $9 
exit;

