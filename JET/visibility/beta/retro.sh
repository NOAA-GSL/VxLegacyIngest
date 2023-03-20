#!/bin/bash                                                                                                                                           
#SBATCH -J vis_driver_retro
#SBATCH --mail-user=verif-amb.gsl@noaa.gov                                                                                          
#SBATCH --mail-type=FAIL
#SBATCH -A amb-verif
#SBATCH -n 1
#SBATCH -p service 
#SBATCH -t 02:00:00
#SBATCH --mem=2G
#SBATCH -D .
#SBATCH -o /home/amb-verif/visibility/tmp/vis_driver_retro.oe%j
#

echo "$HOME/visibility/beta/vis_driver.pl $1 $2 $3 $4"
$HOME/visibility/beta/vis_driver.pl $1 $2 $3 $4
