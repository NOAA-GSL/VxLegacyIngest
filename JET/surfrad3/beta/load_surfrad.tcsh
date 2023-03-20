#!/bin/tcsh
#
#PBS -d .                                                                                                           
#PBS -N load_surfrad                                                                                                
#PBS -M verif-amb.gsd@noaa.gov                                                                                            
#PBS -m a
#PBS -A amb-verif                                                                                                       
#PBS -l partition=vjet
#PBS -l procs=1                                                                                                     
#PBS -q service                                                                                                     
#PBS -l walltime=01:00:00                                                                                           
#PBS -l vmem=16G                                                                                                     
#PBS -e tmp/                                                                                                        
#PBS -o tmp/
#
#
cd $HOME
source .cshrc
cd $HOME/surfrad3/beta/
unsetenv LD_LIBRARY_PATH
./load_surfrad.py

