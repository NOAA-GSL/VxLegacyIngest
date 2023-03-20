#!/bin/tcsh
#PBS -d .                                                                                                                 
#PBS -N ua_RR1h                                                                                                      
#PBS -A nrtrr                                                                                                             
#PBS -l procs=1                                                                                                           
#PBS -l partition=sjet                                                                                                    
#PBS -q service                                                                                                           
#PBS -l walltime=01:00:00                                                                                                 
#PBS -l vmem=16G                                                                                                           
#PBS -M verif-amb.gsd@noaa.gov                                                                                            
#PBS -m a                                                                                                                 
#PBS -e tmp/                                                                                                              
#PBS -o tmp/      

source $HOME/.cshrc
printenv | sort
$HOME/RR_uaverif/agen_raob_sites4.pl HRRR 0 1


