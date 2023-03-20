#!/usr/bin/perl
#
#SBATCH -J sfc_verif
#SBATCH --mail-user=verif-amb.gsl@noaa.gov
#SBATCH --mail-type=FAIL
#SBATCH -A amb-verif
#SBATCH -n 1
#SBATCH -p service
#SBATCH -t 01:00:00
#SBATCH --mem=16G
#SBATCH -D .
#SBATCH -e /home/amb-verif/ruc_madis_surface/tmp/sfc_verif.e%j
#SBATCH -o /home/amb-verif/ruc_madis_surface/tmp/sfc_verif.o%j
#
use strict;
use English;
my $DEBUG=1;
#
# set up to call locally (from the command prompt)
my $thisDir = $ENV{PBS_O_WORKDIR};
my $qsubbed=1;
unless($thisDir) {
    # we've been called locally instead of qsubbed
    $qsubbed=0;
    use File::Basename; 
    my ($basename,$thisDir2) = fileparse($0);
    $thisDir = $thisDir2;
}
my $output_id = $ENV{PBS_JOBID} || $$;
if($output_id =~/^(\d+)/) {
    $output_id = $1;		# keep only numeric part of jobid
    #print "output_id is $output_id\n";
}

#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";
$thisDir = $ENV{PWD};

use Time::Local;
use DBI;

$|=1;  #force flush of buffers after each print
#open (STDERR, ">&STDOUT") || die "can't dup stdout ($!)\n";
$ENV{CLASSPATH} =
    "/misc/ihome/moninger/javalibs/mysql/mysql-connector-java-3.1.13-bin.jar:".
    ".";

$SIG{ALRM} = \&my_timeout;
my %month_num = (Jan => 1, Feb => 2, Mar => 3, Apr => 4, May => 5, Jun => 6,
		 Jul => 7, Aug => 8, Sep => 9, Oct =>10, Nov =>11, Dec =>12);

my $start_secs = time();
$ENV{'TZ'}="GMT";
my ($aname,$aid,$alat,$alon,$aelev,@description);
my ($found_airport,$lon,$lat,$lon_lat,$time);
my ($location);
my ($startSecs,$endSecs);
my ($file,$type,$fcst_len,$elev,$name,$id,$data,$bad_data);
my ($good_data,$found_sounding_data,$maps_coords,$title,$logFile);
my ($dist,$dir,$differ);
my ($loaded_soundings);
my $n_zero_ceilings=0;;
my $n_stations_loaded=0;
my $valid_str;
my $rh_flag = 0;		# 1 if the rh variable is SPFH, 0 if it is RH

use lib "./";
use Time::Local;    #includes 'timegm' for calculations in gmt
#require "timelocal.pl";   #includes 'timegm' for calculations in gmt
require "/home/amb-verif/ruc_madis_surface/get_iso_file3_backfill.pl";
require "/home/amb-verif/ruc_madis_surface/jy2mdy.pl";
require "/home/amb-verif/ruc_madis_surface/update_summaries_v2.pl";
require "/home/amb-verif/ruc_madis_surface/update_summaries_v3u.pl";
require "/home/amb-verif/ruc_madis_surface/update_summaries_v2_new.pl";
require "/home/amb-verif/ruc_madis_surface/update_summaries_v3u_new.pl";
require "/home/amb-verif/ruc_madis_surface/get_grid.pl";
require "/home/amb-verif/ruc_madis_surface/get_obs_at_hr_q.pl";
require "/home/amb-verif/ruc_madis_surface/update_summaries_vgtyp.pl";
require "/home/amb-verif/ruc_madis_surface/update_summaries_vgtyp_v2.pl";

# connect to the database
$ENV{DBI_DSN} = "DBI:mysql:madis3:wolphin.fsl.noaa.gov";
$ENV{DBI_USER} = "sfc_driver5";
$ENV{DBI_PASS} = "driver5";
my $dbh;

my $reprocess = 0;
my $i_arg = 0;
my $data_source = $ARGV[$i_arg++];
my $start_time = abs($ARGV[$i_arg++]);
my $end_time = abs($ARGV[$i_arg++]);
if (defined $ARGV[$i_arg] && $ARGV[$i_arg] > 0) {
    $reprocess = 1;
}
$i_arg++;
my $nets = $ARGV[$i_arg++] || "all"; # 'metars' to only process metar sites
print "start_time is $start_time\n";
print "end_time is $end_time\n";
print "reprocess is $reprocess\n";

if($qsubbed == 1) {
    my $output_file = "tmp/$data_source.sfc_drq.$output_id.out";
    
# send standard out (and stderr) to $output_File
    use IO::Handle;
    *STDERR = *STDOUT;		# send standard error to standard out
    open OUTPUT, '>',"$output_file" or die $!;
    STDOUT->fdopen( \*OUTPUT, 'w' ) or die $!; # send stdout to output file
}

my $db_machine = "wolphin.fsl.noaa.gov";
my $db_name = "madis3";
my $data_file = "tmp/${data_source}.$$.data";
my $data_1f_file = "tmp/${data_source}.$$.data_1f";
my $coastal_file = "tmp/${data_source}.$$.coastal";
my $coastal_station_file = "tmp/${data_source}.$$.coastal_stations";
my $tmp_file = "tmp/${data_source}.$$.grib_data.tmp";

#my $time = time() - $hours_ago*3600;
# get on appropriate  boundary
#if($data_source =~ /FIM/ ||
#    $data_source =~/NAVGEM/) {
#    $time = $time - $time%(3600*12); # 12-h boundary
#} elsif($data_source =~ /GFS/) {
#    $time = $time - $time%(3600*6); # 6-h boundary
#} else{
#    $time = $time - $time%3600; # 1-h boundary
#}

# my @valid_times = ($time,$time-1*3600,$time-2*3600,$time-3*3600,$time-6*3600,$time-9*3600);
#if($data_source =~ /FIM/ ||
#    $data_source =~/NAVGEM/) {
#     @valid_times = ($time,$time-12*3600);
#} elsif($data_source =~ /GFS/) {
#    @valid_times = ($time,$time-6*3600,$time-12*3600);
#}
#print "time2=$time\n";

#my @valid_times = ($time);

my @regions;
my @fcst_lens;
my $WRF;
if($data_source eq "NAMnest_OPS_227") {
    $rh_flag = 1;
    @regions = qw[ALL_RUC E_RUC W_RUC ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI];
    @fcst_lens = (0,1,3,6,9,12,18,24);
    $WRF=1;
} elsif($data_source eq "NAM_NEST_AK") {
    @regions = qw[AK];
    @fcst_lens = (0,1,2,3,6,9,12,15,18,21,24);
    $WRF=1;
} elsif($data_source eq "NAM_NEST_HI") {
    @regions = qw[HI];
    @fcst_lens = (0,1,2,3,6,9,12,15,18,21,24);
    $WRF=1;
} elsif($data_source =~ /NAM/) {
    $rh_flag = 1;
    @regions = qw[ALL_RR1 ALL_RUC E_RUC W_RUC ALL_HRRR E_HRRR W_HRRR AK HWT STMAS_CI];
    # leave out 1h forecasts below; those are
    # generated by surface_driver_all_nets.pl
    @fcst_lens = (0,3,6,9,12);
    $WRF=1;
} elsif($data_source eq "FIM_4") {
    # global half degree grid, grid '4'
    $rh_flag = 1;
    @regions = qw[NHX_E NHX_W NHX Global SHX TRO ALL_RR1 ALL_RUC E_RUC W_RUC
                             ALL_HRRR E_HRRR W_HRRR AK HWT STMAS_CI];
    @fcst_lens = (0,12,24,36,48,60,72);
    $WRF=1;
} elsif($data_source eq "GFS_4") {
    # global half degree grid, grid '4'
    #$rh_flag = 2;
    $rh_flag = 1;
    @regions = qw[NHX_E NHX_W NHX Global SHX TRO ALL_RR1 ALL_RUC E_RUC W_RUC
                             ALL_HRRR E_HRRR W_HRRR AK HWT STMAS_CI];
    @fcst_lens = (0,6,12,18,24,36,48,60,72);
    $WRF=1;
} elsif($data_source eq "FV3_GFS_EMC") {
    # global half degree grid, grid '4'
    #$rh_flag = 2;
    $rh_flag = 1;
    @regions = qw[NHX_E NHX_W NHX Global SHX TRO ALL_RR1 ALL_RUC E_RUC W_RUC
                             ALL_HRRR E_HRRR W_HRRR AK HWT STMAS_CI];
    @fcst_lens = (0,6,12,18,24,36,48,60,72);
    $WRF=1;
} elsif($data_source =~ /NAVGEM/) {
    # global half degree grid, grid '4'
    $rh_flag = 3;		# NAVGEM seems to lack any surface vapor information
    @regions = qw[NHX_E NHX_W NHX Global SHX TRO ALL_RR1 ALL_RUC E_RUC W_RUC
                             ALL_HRRR E_HRRR W_HRRR AK HWT STMAS_CI];
    @fcst_lens = (0,6,12,18,24,36,48,60,72);
    $WRF=1;
}elsif($data_source eq "FIM_130") {
    $rh_flag = 1;
    @regions = qw[ALL_RUC E_RUC W_RUC ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI];
    # leave out 1h forecasts below; those are
    # generated by surface_driver_all_nets.pl
    @fcst_lens = (0,12,24,36,48,60,72);
    $WRF=1;
} elsif($data_source eq "GLMP") {
    @regions = qw[ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI];
    @fcst_lens = (1,3,6,9,12);
    $WRF=1;
} elsif($data_source =~ /RTMA_GSD_3D/) {
    $rh_flag = 1;
    @regions = qw[ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI];
    @fcst_lens = (0);
    $WRF=1;
} elsif($data_source eq "RTMA_GSD") {
    $rh_flag = 1;
    @regions = qw[ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI];
    @fcst_lens = (0);
    $WRF=1;
} elsif($data_source eq "RTMA_GSD_dev1") {
    $rh_flag = 1;
    @regions = qw[ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI];
    @fcst_lens = (0);
    $WRF=1;
} elsif($data_source eq "RUA_dev1") {
    $rh_flag = 1;
    @regions = qw[ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI];
    @fcst_lens = (0);
    $WRF=1;
} elsif($data_source eq "RTMA_OPS") {
    $rh_flag = 1;
    @regions = qw[ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI];
    @fcst_lens = (0);
    $WRF=1;
} elsif($data_source eq "URMA_OPS") {
    $rh_flag = 1;
    @regions = qw[ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI];
    @fcst_lens = (0);
    $WRF=1;
} elsif($data_source eq "RTMA_OPS_hourly") {
    $rh_flag = 1;
    @regions = qw[ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI];
    @fcst_lens = (0);
    $WRF=1;
} elsif($data_source eq "RTMA_v2_7_EMC") {
    $rh_flag = 1;
    @regions = qw[ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI];
    @fcst_lens = (0);
    $WRF=1;
} elsif($data_source eq "RTMA_v2_7_RU_EMC") {
    $rh_flag = 1;
    @regions = qw[ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI];
    @fcst_lens = (0);
    $WRF=1;
} elsif($data_source eq "RAP_OPS_iso_242") {
    @regions = qw[AK];
    @fcst_lens = (0,1,2,3,6,9,12);
    $WRF=1;
} elsif($data_source eq "RAP_NCOpara_iso_242") {
    @regions = qw[AK];
    @fcst_lens = (1,3,6,9,12);
    $WRF=1;
} elsif($data_source eq "HRRR") {
    @regions = qw[ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI ICICLE NORTHWEST];
    # leave out 1h forecasts below; those are
    # generated by surface_driver_all_nets.pl
    @fcst_lens = (0,2,3,6,9,12,15,18,21,24,27,30,33,36);
    $WRF=1;
}  elsif($data_source eq "RAP_NCO_gfsv16_test") {
    @regions = qw[ALL_RR1 ALL_RUC E_RUC W_RUC ALL_HRRR E_HRRR W_HRRR AK HWT STMAS_CI HI];
    @fcst_lens = (0,1,2,3,6,9,12,18,24,30,36);
    $WRF=1;
} elsif($data_source eq "HRRR_NCO_gfsv16_test") {
    @regions = qw[ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI];
    @fcst_lens = (0,1,2,3,6,9,12,15,18,21,24,27,30,33,36);
    $WRF=1;
} elsif($data_source eq "HRRR_AK_NCO_gfsv16_test") {
    @regions = qw[AK];
    @fcst_lens = (0,1,2,3,6,9,12,15,18,21,24,27,30,33,36);
    $WRF=1;
} elsif($data_source eq "HRRR_smoke") {
    @regions = qw[ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI NORTHWEST];
    @fcst_lens = (0,1,2,3,6,9,12,15,18,21,24,27,30,33,36);
    $WRF=1;
} elsif($data_source eq "HRRR_NEST_ICICLE") {
    @regions = qw[ICICLE];
    @fcst_lens = (0,1,2,3,6,9,12,15,18,21,24);
    $WRF=1;
} elsif($data_source eq "HRRR_NEST_ICICLE_dev") {
    @regions = qw[ICICLE];
    @fcst_lens = (0,1,2,3,6,9,12,15,18,21,24);
    $WRF=1;
} elsif($data_source eq "HRRRv3_EMC") {
    @regions = qw[ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI];
    @fcst_lens = (0,1,2,3,6,9,12,15,18,21,24,27,30,33,36);
    $WRF=1;
} elsif($data_source eq "HRRRv3_NCO") {
    @regions = qw[ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI];
    @fcst_lens = (0,1,2,3,6,9,12,15,18,21,24,27,30,33,36);
    $WRF=1;
} elsif($data_source eq "HRRR_HI") {
    @regions = qw[HI];
    @fcst_lens = (0,1,2,3,6,9,12,15,18,21,24,27,30,33,36);
    $WRF=1;
} elsif($data_source =~ /HRRRE_mem/) {
    @regions = qw [E_HRRR HWT STMAS_CI];
    @fcst_lens = (0,1,2,3,6,9,12,15,18,21,24,27,30,33,36);
    $WRF=1;
} elsif($data_source eq "HRRR_AK") {
    @regions = qw[AK];
    # get 1h forecasts from the 'all_nets' run
    @fcst_lens = (0,2,3,6,9,12,15,18,21,24,27,30,33,36);
    $WRF=1;
} elsif($data_source eq "HRRRv3_NCO_AK") {
    @regions = qw[AK];
    # get 1h forecasts from the 'all_nets' run
    @fcst_lens = (0,2,3,6,9,12,15,18,21,24,27,30,33,36);
    $WRF=1;
} elsif($data_source eq "HRRR_AK_dev") {
    @regions = qw[AK];
    # get 1h forecasts from the 'all_nets' run
    @fcst_lens = (0,2,3,6,9,12,15,18,21,24,27,30,33,36);
    $WRF=1;
} elsif($data_source eq "HRRR_AK_OPS") {
    @regions = qw[AK];
    # get 1h forecasts from the 'all_nets' run
    @fcst_lens = (0,2,3,6,9,12,15,18,21,24,27,30,33,36);
    $WRF=1;
} elsif($data_source eq "HRRR_dev3") {
    @regions = qw[ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI];
    @fcst_lens = (0,1,2,3,6,9,12,15,18,21,24,27,30,33,36);
    $WRF=1;
} elsif($data_source eq "HRRR_NREL") {
    @regions = qw[ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI];
    @fcst_lens = (0,1,2,3,6,9,12,15,18,21,24,27,30,33,36,39,42,45,48);
    $WRF=1;
} elsif($data_source eq "HRRR_AQPI_1km_SFO") {
    @regions = qw[SFO];
    @fcst_lens = (0,1,2,3,6,9,12,15,18,21,24);
    $WRF=1;
} elsif($data_source eq "HRRR_OPS") {
    $rh_flag = 1;
    @regions = qw[ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI NORTHWEST];
    # leave out 1h forecasts below; those are
    # generated by surface_driver_all_nets.pl
    @fcst_lens = (0,2,3,6,9,12,15,18);
    $WRF=1;
} elsif($data_source eq "HRRRv2_NCO") {
    $rh_flag = 1;
    @regions = qw[ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI];
    # leave out 1h forecasts below; those are
    # generated by surface_driver_all_nets.pl
    @fcst_lens = (0,2,3,6,9,12,15,18);
    $WRF=1;
} elsif($data_source eq "HRRR_WFIP2") {
    $rh_flag = 1;
    @regions = qw[ALL_HRRR E_HRRR W_HRRR HWT];
    # leave out 1h forecasts below; those are
    # generated by surface_driver_all_nets.pl
    @fcst_lens = (0,2,3,6,9,12);
    $WRF=1;
} elsif($data_source =~ /HRRR/) {
    # other versions of HRRR
    @regions = qw[ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI ICICLE NORTHWEST S_PLAINS];
    @fcst_lens = (0,1,2,3,6,9,12,15,18,21,24,27,30,33,36,39,42,45,48);
    $WRF=1;
}  elsif($data_source eq "RR1h") {
    @regions = qw[ALL_RR1 ALL_RUC E_RUC W_RUC ALL_HRRR E_HRRR W_HRRR AK HWT STMAS_CI HI NORTHWEST];
    # leave out 1h forecasts below; those are
    # generated by surface_driver_all_nets.pl
    @fcst_lens = (0,2,3,6,9,12,18,24,30,36);
    $WRF=1;
}  elsif($data_source eq "RAPv4_EMC") {
    @regions = qw[ALL_RR1 ALL_RUC E_RUC W_RUC ALL_HRRR E_HRRR W_HRRR AK HWT STMAS_CI HI];
    @fcst_lens = (0,1,2,3,6,9,12,18,24,30,36);
    $WRF=1;
}  elsif($data_source eq "RAPv4_EMC_130") {
    @regions = qw[ALL_RUC E_RUC W_RUC ALL_HRRR E_HRRR W_HRRR];
    @fcst_lens = (0,1,2,3,6,9,12,18,24,30,36);
    $WRF=1;
}  elsif($data_source eq "RAPv4_NCO") {
    @regions = qw[ALL_RR1 ALL_RUC E_RUC W_RUC ALL_HRRR E_HRRR W_HRRR AK HWT STMAS_CI HI];
    @fcst_lens = (0,1,2,3,6,9,12,18,24,30,36);
    $WRF=1;
}  elsif($data_source eq "RAP_NCO_noIVEA") {
    @regions = qw[ALL_RR1 ALL_RUC E_RUC W_RUC ALL_HRRR E_HRRR W_HRRR AK HWT STMAS_CI HI];
    @fcst_lens = (0,1,2,3,6,9,12,18,24,30,36);
    $WRF=1;
}  elsif($data_source eq "RAPv4_NCO_130") {
    @regions = qw[ALL_RUC E_RUC W_RUC ALL_HRRR E_HRRR W_HRRR];
    @fcst_lens = (0,1,2,3,6,9,12,18,24,30,36);
    $WRF=1;
}  elsif($data_source eq "RAP_NCEP_full") {
    $rh_flag = 1;
    @regions = qw[ALL_RR1 ALL_RUC E_RUC W_RUC ALL_HRRR E_HRRR W_HRRR AK HWT STMAS_CI HI NORTHWEST];
    # 1h forecast is handled by surface_driver_all_nets
    @fcst_lens = (0,2,3,6,9,12,18,24,30,36);
    $WRF=1;
}  elsif($data_source eq "RAP_OPS_WCOSS") {
    @regions = qw[ALL_RR1 ALL_RUC E_RUC W_RUC ALL_HRRR E_HRRR W_HRRR AK HWT STMAS_CI HI NORTHWEST];
    @fcst_lens = (0,1,2,3,6,9,12,18);
    $WRF=1;
}  elsif($data_source eq "RAP_OPS_WCOSS2_a") {
    @regions = qw[ALL_RR1 ALL_RUC E_RUC W_RUC ALL_HRRR E_HRRR W_HRRR AK HWT STMAS_CI HI NORTHWEST];
    @fcst_lens = (0,1,2,3,6,9,12,18);
    $WRF=1;
}  elsif($data_source eq "RR1h_dev") {
    @regions = qw[ALL_RR1 ALL_RUC E_RUC W_RUC ALL_HRRR E_HRRR W_HRRR AK HWT STMAS_CI];
    # leave out 1h forecasts below; those are
    # generated by surface_driver_all_nets.pl
    @fcst_lens = (0,2,3,6,9,12);
    $WRF=1;
}  elsif($data_source eq "RR1h_dev2") {
    @regions = qw[ALL_RR1 ALL_RUC E_RUC W_RUC ALL_HRRR E_HRRR W_HRRR AK HWT STMAS_CI];
    # leave out 1h forecasts below; those are
    # generated by surface_driver_all_nets.pl
    @fcst_lens = (0,2,3,6,9,12);
    $WRF=1;
}  elsif($data_source eq "RRrapx") {
    # RRrapx is on 130 grid (CONUS)
    @regions = qw[ALL_RUC E_RUC W_RUC ALL_HRRR E_HRRR W_HRRR];
    @fcst_lens = (0,1,2,3,6,9,12,15,18,21,24,27,30);
    #@fcst_lens = (1);
    $WRF=1;  
}  elsif($data_source eq "RAP_NCEP") {
    # RRrap is on 130 grid (CONUS)
    @regions = qw[ALL_RUC E_RUC W_RUC ALL_HRRR E_HRRR W_HRRR];
    @fcst_lens = (1,0,2,3,6,9,12);
    #@fcst_lens = (1);
    $WRF=1;
}  elsif($data_source eq "RAPv3_NCO") {
    @regions = qw[ALL_RUC E_RUC W_RUC ALL_HRRR E_HRRR W_HRRR];
    @fcst_lens = (1,0,2,3,6,9,12,15,18,21);
    #@fcst_lens = (1);
    $WRF=1;
}  elsif($data_source eq "RAPv3_NCO_iso_130") {
    @regions = qw[ALL_RUC E_RUC W_RUC ALL_HRRR E_HRRR W_HRRR];
    @fcst_lens = (1,0,2,3,6,9,12,15,18,21);
    #@fcst_lens = (1);
    $WRF=1;
} elsif($data_source eq "RUA") {
    @regions = qw[ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI];
    @fcst_lens = (0);
    $WRF=1;
} elsif($data_source eq "RUA_AK") {
    @regions = qw[AK];
    @fcst_lens = (0);
    $WRF=1;
}  elsif($data_source =~ /^RR/) {
    # other versions of RR... models, NOT the two just above
    @regions = qw[ALL_RR1 ALL_RUC E_RUC W_RUC ALL_HRRR E_HRRR W_HRRR];
    @fcst_lens = (1,0,2,3,6,9,12);
    #@fcst_lens = (1);
    $WRF=1;
} elsif($data_source =~ /13/) {
    @regions = qw[ALL_RUC E_RUC W_RUC ALL_HRRR E_HRRR W_HRRR];
    #@regions = qw[ALL_RUC];
    @fcst_lens = (1,0,2,3,6,9,12);
    #@fcst_lens = (1);
    $WRF=0;
}
# see if the needed tables exist                                                                                
$dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
$dbh->do("use madis3");
#my $query = qq(show tables like "$data_source%");
my $query = qq(show tables like "${data_source}qp%");
my $result = $dbh->selectrow_array($query);
unless($result) {
   # create needed tables                                                                                      
    print "CREATING TABLES IN DATABASE\n";
#    $query = "create table madis3.${data_source}qp like madis3.RR1hqp";
    $query = "create table madis3.${data_source}qp like madis3.real_template_qp";
    print "$query\n";
    $dbh->do($query);
#    $query = "create table madis3.${data_source}qp1f like madis3.RR1hqp1f";
    $query = "create table madis3.${data_source}qp1f like madis3.real_template_qp1f";
    print "$query\n";
    $dbh->do($query);
    $query = "create table madis3.${data_source}_coastal5 like madis3.RR1h_coastal5";
    print "$query\n";
    $dbh->do($query);
    $query = "create table madis3.stations_${data_source}_coastal5 ".
        "like madis3.stations_RR1h_coastal5";
    print "$query\n";
    $dbh->do($query);
    $dbh->do("use surface_sums2");
    print "use surface_sums2\n";
    foreach my $region (@regions) {
	my $table = "${data_source}_metar_v2_${region}";
	$query = qq[create table $table like RR1h_metar_v2_ALL_HRRR];
	print "$query\n";
	$dbh->do($query);
    }
}
$dbh->disconnect();


#foreach my $valid_time (@valid_times) {
for (my $valid_time = $start_time; $valid_time <= $end_time; $valid_time += 3600) {
$valid_str = gmtime($valid_time);
foreach $fcst_len (@fcst_lens) {
#foreach $fcst_len ((0)) {
my $run_time = $valid_time - $fcst_len * 3600;
my $valid_date = sql_datetime($valid_time);

if($reprocess == 0 &&
   already_processed($data_source,$valid_time,$fcst_len,$regions[0],$DEBUG)) {
    print "\nALREADY LOADED: $data_source $fcst_len h fcst valid at $valid_str\n";
    next;
} else {
    print "\nTO PROCESS: $fcst_len h fcst valid at $valid_str\n";
}

my $start = "";			# not looking for 'latest'
($file,$type) =
    &get_iso_file3($run_time,$data_source,$DEBUG,$fcst_len,
		    $start);

my($run_year,$run_month_num,$run_mday,$run_hour,$run_fcst_len);

unless($file) {
    print "file not found for $data_source $fcst_len h fcst valid at $valid_str.\n";
    next;
} else {
    print "FILE FOUND $data_source $fcst_len h fcst valid at $valid_str\n";
}
# get grid details
my($la1,$lo1,$lov,$latin1,$nx,$ny,$dx,$grib_type,$grid_type,$valid_date_from_file,$fcst_proj,$wind_rot_flag)
    = get_grid($file,$thisDir,$DEBUG);
# change 'undef' to zeros for use in the $arg_unsafe argument list
$la1+=0;
$lo1+=0;
$lov+=0;
$latin1+=0;
$nx+=0;
$ny+=0;
$dx+=0;
if(1) {
    print "grib_type is $grib_type. |$la1| |$lo1| |$lov| |$latin1| ".
	"|$nx| |$ny| |$dx|\n";
    print ("valid times from get_grid: $valid_date_from_file,$fcst_proj\n");
}



if($valid_date_from_file != $valid_date) {
    print "BAD VALID DATE from file: $valid_date_from_file\n";
    exit(1);
}
$dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
get_obs_at_hr_q($valid_time,$dbh);
$dbh->disconnect();

my $arg_unsafe;
if($WRF == 1) {
    $arg_unsafe = "${thisDir}/surface_HRRR_q.x ".
	"$nets $data_source $valid_time $file $tmp_file $grib_type $grid_type $fcst_len ".
	"$la1 $lo1 $lov $latin1 $dx ".
	"$nx $ny 1 $data_file $data_1f_file $coastal_file $coastal_station_file ".
	"$rh_flag $DEBUG";
    $arg_unsafe =~ /([a-zA-Z0-9\.\/\~\_\-\, ]*)/;
    my $arg = $1;
    if($DEBUG) {
	print "arg is $arg\n";
    }
    open(CEIL,"$arg |") ||
	die "cannot execute $arg: $!";
    while(<CEIL>) {
	if($DEBUG) {print;}
	if(/(\d+) stations loaded/) {
	    $n_stations_loaded = $1;
	}
    }
    print "zeros: $n_zero_ceilings, loaded: $n_stations_loaded\n";
    close CEIL;
    my $exit_code = $? >> 8;
    if($exit_code != 0) {
	printf("trouble executing $arg\n");
	printf("exit code is $exit_code\n");
	exit($exit_code);
    }
} elsif($WRF == 0) {
    my $dx_km = $dx/1000;
    $arg_unsafe = "${thisDir}/agrib_madis_sites_q.x $nets $db_machine $db_name ".
	"$data_source $grib_type $valid_time $file $fcst_len ".
	"$la1 $lo1 $lov $latin1 $dx_km ".
	"$nx $ny 1 $data_file $data_1f_file $coastal_file $coastal_station_file ".
	"$DEBUG";
    $arg_unsafe =~ /([a-zA-Z0-9\.\/\~\_\-\, ]*)/;
    my $arg = $1;
    if($DEBUG) {
	print "arg is $arg\n";
    }
   open(CEIL,"$arg |") ||
	die "cannot execute $arg: $!";
    while(<CEIL>) {
	if($DEBUG) {print;}
	if(/(\d+) stations loaded/) {
	    $n_stations_loaded = $1;
	}
    }
    print "zeros: $n_zero_ceilings, loaded: $n_stations_loaded\n";
    close CEIL;
    
}    


if($n_stations_loaded > 0) {
    $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
    foreach my $region (@regions) {
	print "GENERATING SUMMARIES for $data_source,$valid_time,$fcst_len,$region\n\n";
#	update_summaries_v2($data_source,$valid_time,$fcst_len,$region,$dbh,$db_name,1);
	update_summaries_v2_new($data_source,$valid_time,$fcst_len,$region,$dbh,$db_name,1);
#	update_summaries_v3u($data_source,$valid_time,$fcst_len,$region,$dbh,$db_name,1);
	update_summaries_v3u_new($data_source,$valid_time,$fcst_len,$region,$dbh,$db_name,1);
    }
    #update_summaries_vgtyp($data_source,$valid_time,$fcst_len,$dbh,$db_name,1);
    update_summaries_vgtyp_v2($data_source,$valid_time,$fcst_len,$db_name,1);
   $dbh->disconnect();
} else {
    print "NOT GENERATING SUMMARIES\n\n";
}
}}

#finish up
unlink($tmp_file);
unlink($data_file);
unlink($data_1f_file);
unlink($coastal_file);
unlink($coastal_station_file);

# clean up tmp directory
opendir(DIR,"tmp") ||
    die "cannot open tmp/: $!\n";
my @allfiles = grep !/^\.\.?$/,readdir DIR;
foreach my $file (@allfiles) {
    $file = "tmp/$file";
    #print "file is $file\n";
    # untaint
    $file =~ /(.*)/;
    $file = $1;
    if(-M $file > 1) {
        print "unlinking $file\n";
        unlink "$file" || print "Can't unlink $file $!\n";
    }
}
closedir DIR;
my $end_secs = time();
my $diff_secs = $end_secs - $start_secs;
print "NORMAL TERMINATION after $diff_secs secs\n";


sub already_processed {
    my ($data_source,$valid_time,$fcst_len,$region,$DEBUG) = @_;
    my $sec_of_day = $valid_time%(24*3600);
    my $desired_hour = $sec_of_day/3600;
    my $desired_valid_day = $valid_time - $sec_of_day;
    my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
    my $query =<<"EOI"
select N_drh from surface_sums2.${data_source}_metar_v2_${region}
where valid_day = $desired_valid_day and hour = $desired_hour and fcst_len = $fcst_len
EOI
;
    print "query is \n$query\n";
    #print "query is $query\n";
    my $sth = $dbh->prepare($query);
    $sth->execute();
    my($n);
    $sth->bind_columns(\$n);
    $sth->fetch();
    $sth->finish();
    # for debugging:
    #$n=0;
    #print "n returned is $n\n";
    $dbh->disconnect();
    return $n;
}


