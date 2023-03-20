#!/bin/tcsh
#
#SBATCH -J SURFRAD3_clean
#SBATCH --mail-user=verif-amb.gsl@noaa.gov
#SBATCH --mail-type=FAIL
#SBATCH -A amb-verif
#SBATCH -n 1
#SBATCH -p vjet,xjet
#SBATCH -t 03:59:00
#SBATCH -D .
#SBATCH --mem=2G
#SBATCH -o tmp/SURFRAD3_clean.oe%j
#
#
source $HOME/.cshrc
#set dir=`/usr/bin/dirname $0`
cd $HOME/surfrad3/
#echo "PWD is $PWD"
#unsetenv GRIB_DEFINITION_PATH
#./multiprocess_models.py $1 $2 $3 $4 $5
# remove files in the tmp directory older than 12 h
echo "removing 16h old files in the tmp/ directory"
find ./tmp/ -mmin +960 -name "*.*" -exec rm -f {} \;
exit 0
