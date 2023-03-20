#!/bin/tcsh
#
#PBS -d .                                                                                                           
#PBS -N ld_pcp_mesonets                                                                                                
#PBS -M verif-amb.gsd@noaa.gov                                                                                            
#PBS -m a
#PBS -A amb-verif                                                                                                       
#PBS -l partition=ujet:tjet:sjet:vjet:xjet 
#PBS -l nodes=1:ppn=1
#PBS -q service                                                                                                     
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
unsetenv LD_LIBRARY_PATH   # needed to get the 'official' python which has MySQLdb
./load_mysql.py
