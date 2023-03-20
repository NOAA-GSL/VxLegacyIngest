#!/bin/tcsh
#
#SBATCH -J ld_pcp_1min
#SBATCH --mail-user=verif-amb.gsl@noaa.gov                                                                                          
#SBATCH --mail-type=FAIL
#SBATCH -A amb-verif
#SBATCH -n 1
#SBATCH -p service 
#SBATCH -t 01:00:00
#SBATCH --mem=16G
#SBATCH -D .
#SBATCH -e /home/amb-verif/precip_1min/tmp/ld_pcp_1min.e%j
#SBATCH -o /home/amb-verif/precip_1min/tmp/ld_pcp_1min.o%j
#
#
source $HOME/.cshrc
cd $HOME/precip_1min/
#echo "PWD is $PWD"
# remove files in the tmp directory older than 24 h
echo "removing 24h old files in the tmp/ directory"
find ./tmp/ -mmin +1440 -name "*.*" -exec rm -f {} \;
unsetenv LD_LIBRARY_PATH   # needed to get the 'official' python which has MySQLdb
./load_mysql.py
