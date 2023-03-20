#!/bin/tcsh
#
#PBS -d .                                                                                                           
#PBS -N gen_surfrad                                                                                                
#PBS -M verif-amb.gsd@noaa.gov                                                                                            
#PBS -m a
#PBS -A amb-verif                                                                                                       
#PBS -l partition=vjet
#PBS -l nodes=1:ppn=16
#PBS -q batch                                                                                                     
#PBS -l walltime=01:00:00                                                                                           
#PBS -l vmem=16G                                                                                                     
#PBS -e tmp/                                                                                                        
#PBS -o tmp/
#
#
source $HOME/.cshrc
#set dir=`/usr/bin/dirname $0`
cd $HOME/surfrad3/
#echo "PWD is $PWD"
unsetenv GRIB_DEFINITION_PATH
./multiprocess_models_test.py $1 $2
# remove files in the tmp directory older than 12 h
echo "removing 12h old files in the tmp/ directory"
find ./tmp/ -mmin +720 -name "*.*" -exec rm -f {} \;

