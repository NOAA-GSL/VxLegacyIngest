#!/bin/tcsh
#
#SBATCH -J load_pm2p5
#SBATCH --mail-user=verif-amb.gsl@noaa.gov
#SBATCH --mail-type=FAIL
#SBATCH -A amb-verif
#SBATCH -n 1
#SBATCH -p service
#SBATCH -t 00:50:00
#SBATCH -D /home/amb-verif/airnow/
#SBATCH --mem=16G
#SBATCH -o tmp/load_pm2p5.o%j
#
#
source $HOME/.cshrc
cd $HOME/airnow/
#echo "PWD is $PWD"
# remove files in the tmp directory older than 24 h
echo "removing 24h old files in the tmp/ directory"
find ./tmp/ -mmin +1440 -name "*.*" -exec rm -f {} \;

# need to use the DEFAULT python to use MySQLdb
#unsetenv LD_LIBRARY_PATH
./load_pm2p5.py
