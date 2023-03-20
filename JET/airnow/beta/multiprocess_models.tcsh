#!/bin/tcsh
#
#SBATCH -J airnow_verif
#SBATCH --mail-user=William.R.Moninger@noaa.gov
#SBATCH --mail-type=FAIL
#SBATCH -A amb-verif
#SBATCH -n 1
#SBATCH -t 00:50:00
#SBATCH -D /home/amb-verif/airnow/beta/
#SBATCH --mem=16G
#SBATCH -o tmp/airnow_verif.o%j
#
#
source $HOME/.cshrc
cd $HOME/airnow/beta/
# remove files in the tmp directory older than 12 h
echo "removing 12h old files in the tmp/ directory"
find ./tmp/ -mmin +720 -name "*.*" -exec rm -f {} \;

./multiprocess_models.py $1 $2
