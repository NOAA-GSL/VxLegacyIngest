#!/bin/bash
#source #HOME/.bashrc
#
#PBS -N ceiling_retro
#PBS -M Jeffrey.A.Hamilton@noaa.gov
#PBS -m a
#PBS -A amb-verif
#PBS -l procs=1
#PBS -q service
#PBS -l walltime=00:59:00
#PBS -l vmem=2G
#PBS -d .
#PBS -e tmp/
#PBS -o tmp/

$HOME/ceiling/ceil_driver_retro.pl RRret_protoRAPv4_summer4 1467374400 1470052800
