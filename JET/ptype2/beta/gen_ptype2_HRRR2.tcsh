#!/bin/tcsh
#
#SBATCH -J ptype2_verif
#SBATCH --mail-user=verif-amb.gsl@noaa.gov
#SBATCH --mail-type=FAIL
#SBATCH -A amb-verif
#SBATCH -n 16
#SBATCH -p vjet,xjet
#SBATCH -t 00:50:00
#SBATCH -D .
#SBATCH --mem=16G
#SBATCH -o tmp/SURFRAD3_verif.o%j
#
#
cd $HOME
source ./.cshrc
cd $HOME/ptype2/beta/
# remove files in the tmp directory older than 12 h
echo "removing 12h old files in the tmp/ directory"
find ./tmp/ -mmin +720 -name "*.*" -exec rm -f {} \;
./multiprocess_HRRR2.py $1 $2

