#!/bin/tcsh
#
#SBATCH -J ld_pcp_mesonets
#SBATCH --mail-user=verif-amb.gsl@noaa.gov                                                                                          
#SBATCH --mail-type=FAIL
#SBATCH -A amb-verif
#SBATCH -n 1
#SBATCH -p service 
#SBATCH -t 01:30:00  # but job will terminate itself after 1 hour
#SBATCH --mem=16G
#SBATCH -D .
#SBATCH -o /home/amb-verif/precip_mesonets2/tmp/ld_pcp_mesonets.o%j
#
#
source $HOME/.cshrc
cd $HOME/precip_mesonets2/
#echo "PWD is $PWD"
# remove files in the tmp directory older than 24 h
echo "removing 24h old files in the tmp/ directory"
find ./tmp/ -mmin +1440 -name "*.*" -exec rm -f {} \;

./load_mysql2.py
