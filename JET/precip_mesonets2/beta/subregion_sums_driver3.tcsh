#!/bin/tcsh
#
#SBATCH -J nets2_sums3
#SBATCH --mail-user=william.r.moninger@noaa.gov                                                                                        
#SBATCH --mail-type=FAIL
#SBATCH -A amb-verif
#SBATCH -n 1
#SBATCH -p service 
#SBATCH -t 01:30:00 
#SBATCH --mem=16G
#SBATCH -D .
#SBATCH -o tmp/nets2_sums3.oe%j
#
# remove files in the tmp directory older than 24 h
echo "removing 24h old files in the tmp/ directory"
find ./tmp/ -mmin +1440 -name "*.*" -exec rm -f {} \;

./subregion_sums_driver3.py $1 $2 $3 $4 $5 $6
