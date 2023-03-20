#!/bin/tcsh
#
#SBATCH -J SURFRAD3_db_load
#SBATCH --mail-user=verif-amb.gsl@noaa.gov
#SBATCH --mail-type=FAIL
#SBATCH -A amb-verif
#SBATCH -n 1
#SBATCH -p service
#SBATCH -t 00:59:00
#SBATCH -D .
#SBATCH --mem=16G
#SBATCH -o tmp/SURFRAD3_db_load.o%j
#SBATCH -e tmp/SURFRAD3_db_load.e%j
#
cd $HOME
source .cshrc
cd $HOME/surfrad3/
#unsetenv LD_LIBRARY_PATH   # needed to get the 'official' python which has MySQLdb

./load_surfrad.py

