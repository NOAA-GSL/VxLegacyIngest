#!/bin/sh --login
#SBATCH -J madis_rr_stats
#SBATCH --mail-user=verif-amb.gsl@noaa.gov
#SBATCH -A amb-verif
#SBATCH --mail-type=FAIL
#SBATCH -n 1
#SBATCH -p service
#SBATCH -t 04:00:00
#SBATCH --mem=1G
#SBATCH -D .
#SBATCH -o /home/amb-verif/ruc_madis_surface/tmp/madis_rr_stats.oe%j

#$HOME/ruc_madis_surface/make_stats_rr.py RR1h 7
#$HOME/ruc_madis_surface/make_mesonet_uselist_RR.3.pl

$HOME/ruc_madis_surface/make_stats_rr.py RAP_NCEP_full 7
$HOME/ruc_madis_surface/make_mesonet_uselist_RAP_OPS.3.pl
