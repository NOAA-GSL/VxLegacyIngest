#!/bin/tcsh

###SBATCH -J vis_verif # name now given as an argument to ~/utilities/sb2.sh
#SBATCH --mail-user=verif-amb.gsl@noaa.gov
#SBATCH --mail-type=FAIL
#SBATCH -A amb-verif
#SBATCH -n 1
#SBATCH -p service
#SBATCH -t 01:00:00
#SBATCH --mem=16G
#SBATCH -D .
#SBATCH -o tmp/vis_verif_backfill.oe%j

# this assumes ~/utilities/sb2.sh puts us in the right directory

source $HOME/.cshrc

./vis_driver_backfill2.pl $1 $2 $3 $4 $5

