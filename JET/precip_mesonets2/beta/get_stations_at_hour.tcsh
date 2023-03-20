#!/bin/tcsh
#
#SBATCH -J get_hourly_pcp_mesonets
#SBATCH --mail-user=verif-amb.gsl@noaa.gov                                                                                          
#SBATCH --mail-type=FAIL
#SBATCH -A amb-verif
#SBATCH -n 1
#SBATCH -p service 
#SBATCH -t 01:01:00
#SBATCH --mem=1G
#SBATCH -D .
#SBATCH -o /home/amb-verif/precip_mesonets2/beta/tmp/get_hourly_pcp_mesonets.oe%j
#
#
source $HOME/.cshrc

#echo "PWD is $PWD"
# remove files in the tmp directory older than 24 h
echo "removing 24h old files in the tmp/ directory"
find ./tmp/ -mmin +1440 -name "*.*" -exec rm -f {} \;

./get_stations_at_hour.py $1 $2 $3
