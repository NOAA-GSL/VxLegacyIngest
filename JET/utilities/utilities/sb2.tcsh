#!/bin/tcsh

echo `dirname $2`
cd `dirname $2`
source ${HOME}/.cshrc
source ${HOME}/.cshrc

echo "sbatch -J ${HOST}_$1 $2 $3 $4 $5 $6 $7 $8 $9" 
/apps/slurm/default/bin/sbatch -J ${HOST}_$1 $2 $3 $4 $5 $6 $7 $8 $9 
exit;

