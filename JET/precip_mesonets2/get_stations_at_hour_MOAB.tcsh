#!/bin/tcsh
#
#PBS -d .                                                                                                           
#PBS -N get_hourly_pcp_mesonets                                                                                                
#PBS -M verif-amb.gsd@noaa.gov                                                                                            
#PBS -m a
#PBS -A amb-verif                                                                                                       
#PBS -l partition=ujet:tjet:sjet:vjet:xjet 
#PBS -l nodes=1:ppn=1
#PBS -q service                                                                                                     
#PBS -l walltime=01:01:00                                                                                           
#PBS -l vmem=1G                                                                                                     
#PBS -e tmp/                                                                                                        
#PBS -o tmp/
#
#
source $HOME/.cshrc
cd $HOME/precip_mesonets2/
#echo "PWD is $PWD"
# remove files in the tmp directory older than 24 h
echo "removing 24h old files in the tmp/ directory"
find ./tmp/ -mmin +1440 -name "*.*" -exec rm -f {} \;

./get_stations_at_hour.py $1 $2 $3
