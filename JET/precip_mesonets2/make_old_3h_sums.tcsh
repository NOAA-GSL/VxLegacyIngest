#!/bin/tcsh
#
#SBATCH -J make_old_3h_sums
#SBATCH --mail-user=verif-amb.gsl@noaa.gov                                                                                          
#SBATCH --mail-type=FAIL
#SBATCH -A amb-verif
#SBATCH -n 1
#SBATCH -p service 
#SBATCH -t 01:00:00
#SBATCH --mem=16G
#SBATCH -D .
#SBATCH -o /home/amb-verif/precip_mesonets2/tmp/make_old_3h_sums.o%j
#
#
source $HOME/.cshrc
cd $HOME/precip_mesonets2/beta/
#echo "PWD is $PWD"

./make_old_3h_sums.py $1 $2
