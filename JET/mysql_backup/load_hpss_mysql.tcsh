#!/bin/tcsh
#
#SBATCH -J ld_hpss_mysql
#SBATCH --mail-user=verif-amb.gsl@noaa.gov                                                                           
#SBATCH --mail-type=FAIL
#SBATCH -A amb-verif
#SBATCH -n 1
#SBATCH -p service 
#SBATCH -t 01:30:00
#SBATCH --mem=16G
#SBATCH -D .
#SBATCH -o tmp/ld_hpss_mysql.oe%j

# remove files in the tmp directory older than 24 h
echo "removing 24h old files in the tmp/ directory"
find ./tmp/ -mmin +1440 -name "*.*" -exec rm -f {} \;

module load hpss
./load_hpss_mysql.py
