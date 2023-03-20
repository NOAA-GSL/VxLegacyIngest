#!/bin/sh -login
# get login environment, which is needed by sbatch

echo `dirname $2`
cd `dirname $2`
echo "sbatch -J ${HOST}_$1 $2 $3 $4 $5 $6 $7 $8 $9" 
/apps/slurm/default/bin/sbatch -J ${HOST}_$1 $2 $3 $4 $5 $6 $7 $8 $9 
exit;

