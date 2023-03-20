#!/bin/tcsh
#
#PBS -d .                                                                                                           
#PBS -N gen_surfrad                                                                                                
#PBS -M verif-amb.gsd@noaa.gov                                                                                            
#PBS -m a
#PBS -A nrtrr                                                                                                       
#PBS -l partition=njet
#PBS -l nodes=1:ppn=8
#PBS -q batch                                                                                                     
#PBS -l walltime=01:00:00                                                                                           
#PBS -l vmem=16G                                                                                                     
#PBS -e tmp/                                                                                                        
#PBS -o tmp/
#
#
source $HOME/.cshrc
#set dir=`/usr/bin/dirname $0`
cd $HOME/surfrad/beta/
#echo "PWD is $PWD"
./multiprocess_HRRR.py $1 $2
# remove files in the tmp directory older than 12 h
echo "removing 12h old files in the tmp/ directory"
find ./tmp/ -mmin +720 -name "*.*" -exec rm -f {} \;

