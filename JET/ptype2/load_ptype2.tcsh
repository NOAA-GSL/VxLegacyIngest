#!/bin/tcsh
#
#SBATCH -J ptype2_db_load
#SBATCH --mail-user=verif-amb.gsl@noaa.gov
#SBATCH --mail-type=FAIL
#SBATCH -A amb-verif
#SBATCH -n 1
#SBATCH -p service
#SBATCH -t 00:50:00
#SBATCH -D .
#SBATCH --mem=16G
#SBATCH -o tmp/ptype2_db_load.o%j
#SBATCH -e tmp/ptype2_db_load.e%j
#

cd $HOME
source ./.cshrc
cd $HOME/ptype2/
./load_ptype2.py

