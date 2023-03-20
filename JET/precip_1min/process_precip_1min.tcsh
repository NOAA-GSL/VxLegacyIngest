#!/bin/tcsh
#
#SBATCH -J pcp_1min
#SBATCH --mail-user=verif-amb.gsl@noaa.gov                                                                                          
#SBATCH --mail-type=FAIL
#SBATCH -A amb-verif
#SBATCH -N 1 --ntasks-per-node=12
#SBATCH -q batch 
#SBATCH -p vjet,xjet 
#SBATCH -t 01:00:00
#SBATCH --mem=16G
#SBATCH -D .
#SBATCH -e /home/amb-verif/precip_1min/tmp/pcp_1min.e%j
#SBATCH -o /home/amb-verif/precip_1min/tmp/pcp_1min.o%j
#
#
source $HOME/.cshrc
cd $HOME/precip_1min/
#echo "PWD is $PWD"
# remove files in the tmp directory older than 24 h
echo "removing 24h old files in the tmp/ directory"
find ./tmp/ -mmin +1440 -name "*.*" -exec rm -f {} \;

./process_precip_1min.py $1 $2 $3
