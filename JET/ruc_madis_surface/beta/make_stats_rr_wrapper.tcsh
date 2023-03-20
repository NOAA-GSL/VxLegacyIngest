#!/bin/sh --login
#PBS -d .                                                                                                           
#PBS -N make_stats_rr                                                                                                
#PBS -M verif-amb.gsd@noaa.gov
#PBS -A amb-verif                                                                                                       
#PBS -l procs=1                                                                                                     
#PBS -l partition=vjet                                                                                              
#PBS -q service                                                                                                     
#PBS -l walltime=01:00:00                                                                                           
#PBS -l vmem=1G                                                                                                     
#PBS -e tmp/                                                                                                        
#PBS -o tmp/

$HOME/ruc_madis_surface/beta/make_stats_rr.py RR1h 7
$HOME/ruc_madis_surface/beta/make_mesonet_uselist_RR.3.pl

$HOME/ruc_madis_surface/beta/make_stats_rr.py RAP_NCEP_full 7
$HOME/ruc_madis_surface/beta/make_mesonet_uselist_RAP_OPS.3.pl
