#!/bin/tcsh
#
#
#SBATCH -J SURFRAD_verif_HRRR
#SBATCH --mail-user=verif-amb.gsl@noaa.gov
#SBATCH --mail-type=FAIL
#SBATCH -A amb-verif
#SBATCH -n 16
#SBATCH -p vjet,xjet
#SBATCH -t 00:50:00
#SBATCH -D .
#SBATCH --mem=16G
#SBATCH -o tmp/SURFRAD_verif_HRRR.o%j
#SBATCH -e tmp/SURFRAD_verif_HRRR.e%j
#

source $HOME/.cshrc
#set dir=`/usr/bin/dirname $0`
cd $HOME/surfrad
#echo "PWD is $PWD"
# remove files in the tmp directory older than 12 h
#echo "removing 12h old files in the tmp/ directory"
#find ./tmp/ -mmin +720 -name "*.*" -exec rm -f {} \;

./multiprocess_HRRR.py $1 $2
