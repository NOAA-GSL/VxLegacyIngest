#!/bin/tcsh
#
#PBS -d .                                                                                                           
#PBS -N pcp_nesonets                                                                                                
#PBS -M verif-amb.gsd@noaa.gov                                                                                            
#PBS -m a
#PBS -A amb-verif                                                                                                       
#PBS -l partition=ujet:tjet:sjet:vjet:xjet 
#PBS -l nodes=1:ppn=12
#PBS -q batch                                                                                                     
#PBS -l walltime=01:00:00                                                                                           
#PBS -l vmem=16G                                                                                                     
#PBS -e tmp/                                                                                                        
#PBS -o tmp/
#
#
source $HOME/.cshrc
cd $HOME/precip_mesonets/
#echo "PWD is $PWD"
# remove files in the tmp directory older than 24 h
echo "removing 24h old files in the tmp/ directory"
find ./tmp/ -mmin +1440 -name "*.*" -exec rm -f {} \;

./process_precip_mesonets.py $1 $2 $3
