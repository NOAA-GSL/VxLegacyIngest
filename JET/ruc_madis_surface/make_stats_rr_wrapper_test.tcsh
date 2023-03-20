#!/bin/sh --login
#PBS -d .                                                                                                           
#PBS -N make_stats_rr                                                                                                
#PBS -A amb-verif                                                                                                       
#PBS -l procs=1                                                                                                     
#PBS -l partition=vjet                                                                                              
#PBS -q service                                                                                                     
#PBS -l walltime=01:00:00                                                                                           
#PBS -l vmem=1G                                                                                                     
#PBS -e tmp/                                                                                                        
#PBS -o tmp/


$HOME/ruc_madis_surface/make_mesonet_uselist_RR.3.pl