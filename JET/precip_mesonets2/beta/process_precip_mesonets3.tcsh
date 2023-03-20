#!/bin/tcsh
#
#SBATCH -J pcp_mesonets3
#SBATCH --mail-user=verif-amb.gsl@noaa.gov                                                                                          
#SBATCH --mail-type=FAIL
#SBATCH -A amb-verif
#SBATCH -N 1 --ntasks-per-node=12
#SBATCH -p vjet,xjet
#SBATCH -t 01:00:00
#SBATCH --mem=16G
#SBATCH -D .
#SBATCH -o tmp/pcp_mesonets2.oe%j
#
#
#source $HOME/.cshrc
#echo "PWD is $PWD"
# remove files in the tmp directory older than 24 h
echo "removing 24h old files in the tmp/ directory"
find ./tmp/ -mmin +1440 -name "*.*" -exec rm -f {} \;

./process_precip_mesonets3.py $1 $2 $3
