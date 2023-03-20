#!/bin/tcsh
#
#PBS -d .                                                                                                           
#PBS -N gen_ptype2                                                                                                
#PBS -M verif-amb.gsd@noaa.gov                                                                                            
#PBS -m a
#PBS -A amb-verif                                                                                                      
#PBS -l partition=tjet:ujet:sjet:vjet:xjet
#PBS -l nodes=1:ppn=12
#PBS -q batch                                                                                                     
#PBS -l walltime=01:00:00                                                                                           
#PBS -l vmem=16G                                                                                                     
#PBS -e tmp/                                                                                                        
#PBS -o tmp/
#
#
cd $HOME
source ./.cshrc
cd $HOME/ptype2/
# remove files in the tmp directory older than 12 h
echo "removing 12h old files in the tmp/ directory"
find ./tmp/ -mmin +720 -name "*.*" -exec rm -f {} \;
./multiprocess_HRRR2.py $1 $2

