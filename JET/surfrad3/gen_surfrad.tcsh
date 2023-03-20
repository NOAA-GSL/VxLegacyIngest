#!/bin/tcsh
#
#SBATCH -J SURFRAD3_verif
#SBATCH --mail-user=verif-amb.gsl@noaa.gov
#SBATCH --mail-type=FAIL
#SBATCH -A amb-verif
#SBATCH -n 16
#SBATCH -p vjet,xjet
#SBATCH -t 06:59:00
#SBATCH -D .
#SBATCH --mem=16G
#SBATCH -o tmp/SURFRAD3_verif.oe%j
#
#
#source $HOME/.cshrc
#set dir=`/usr/bin/dirname $0`
cd $HOME/surfrad3/
#echo "PWD is $PWD"
#unsetenv GRIB_DEFINITION_PATH
./multiprocess_models.py $1 $2 $3 $4 $5
# remove files in the tmp directory older than 12 h
#echo "removing 12h old files in the tmp/ directory"
#find ./tmp/ -mmin +720 -name "*.*" -exec rm -f {} \;

