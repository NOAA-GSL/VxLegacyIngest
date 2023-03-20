#!/usr/bin/perl
#
#PBS -d .
#PBS -N surface_q1
#PBS -A amb-verif
#PBS -l procs=1
#PBS -l partition=vjet
#PBS -q service 
#PBS -l walltime=01:00:00
#PBS -l vmem=16G
#PBS -M verif-amb.gsd@noaa.gov                                                                                          
#PBS -m a
#PBS -e tmp/
#PBS -o tmp/
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
require "./get_iso_file3.pl";
require "./jy2mdy.pl";
require "./update_summaries_v2.pl";
require "./get_grid.pl";
require "./get_obs_at_hr_q.pl";
require "./update_summaries_vgtyp.pl";

# connect to the database
$ENV{DBI_DSN} = "DBI:mysql:madis3:wolphin.fsl.noaa.gov";
$ENV{DBI_USER} = "sfc_driver5";
$ENV{DBI_PASS} = "driver5";
my $dbh;

my $reprocess=0;
my $i_arg=0;
my $data_source = $ARGV[$i_arg++];
my $hours_ago = abs($ARGV[$i_arg++]);
if(defined $ARGV[$i_arg] && $ARGV[$i_arg] > 0) {
    $reprocess=1;
}
$i_arg++;
my $nets = $ARGV[$i_arg++] || "all"; # 'metars' to only process metar sites
print "hours_ago is $hours_ago\n";
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

my $time = time() - $hours_ago*3600;
# get on appropriate  boundary
if($data_source =~ /FIM/ ||
    $data_source =~/NAVGEM/) {
    $time = $time - $time%(3600*12); # 12-h boundary
} elsif($data_source =~ /GFS/) {
    $time = $time - $time%(3600*6); # 6-h boundary
} else{
    $time = $time - $time%3600; # 1-h boundary
}

$time = 1449705600+24*3600;
#my @hr_len = (1..240);
my @hr_len = (601..696);
#my @hr_len = (1..3);
print "time = $time\n";
print "hr_len = @hr_len \n";





my @regions;
my @fcst_lens;
my $WRF;
if($data_source eq "NAMnest_OPS_227") {
    $rh_flag = 1;
#    @regions = qw[ALL_RUC E_RUC W_RUC ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI];
    @regions = qw[ALL_RUC E_RUC W_RUC ];
    @fcst_lens = (0,1,3,6,9,12,18,24);
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
    $rh_flag = 2;
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
} elsif($data_source eq "RTMA_HRRR") {
    $rh_flag = 1;
    @regions = qw[ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI];
    @fcst_lens = (0);
    $WRF=1;
} elsif($data_source eq "RTMA_HRRR_15min") {
    $rh_flag = 1;
    @regions = qw[ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI];
    @fcst_lens = (0);
    $WRF=1;
} elsif($data_source eq "RTMA_dev1") {
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
    @regions = qw[ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI];
    # leave out 1h forecasts below; those are
    # generated by surface_driver_all_nets.pl
    @fcst_lens = (0,2,3,6,9,12,15,18,21,24);
    $WRF=1;
} elsif($data_source eq "HRRR_OPS") {
    $rh_flag = 1;
    @regions = qw[ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI];
    # leave out 1h forecasts below; those are
    # generated by surface_driver_all_nets.pl
    @fcst_lens = (0,2,3,6,9,12);
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
    @regions = qw[ALL_HRRR E_HRRR W_HRRR];
    @fcst_lens = (1,0,2,3,6,9,12);
    $WRF=1;
}  elsif($data_source eq "RR1h") {
    @regions = qw[ALL_RR1 ALL_RUC E_RUC W_RUC ALL_HRRR E_HRRR W_HRRR AK HWT STMAS_CI];
    # leave out 1h forecasts below; those are
    # generated by surface_driver_all_nets.pl
    @fcst_lens = (0,2,3,6,9,12);
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
    $dbh->do("use surface_sums");
    print "use surface_sums\n";
    foreach my $region (@regions) {
	my $table = "${data_source}_metar_v2_${region}";
	$query = qq[create table $table like RR1h_0_metar_q_ALL_HRRR];
	print "$query\n";
	$dbh->do($query);
    }
}
$dbh->disconnect();


#foreach my $valid_time (@valid_times) {
foreach my $hr_loop (@hr_len) {
    my $valid_time = $ time + 3600* $hr_loop;
    $valid_str = gmtime($valid_time);
    foreach $fcst_len (@fcst_lens) {

	my $run_time = $valid_time - $fcst_len * 3600;
	my $valid_date = sql_datetime($valid_time);


    print "\nTO PROCESS: $fcst_len h fcst valid at $valid_str\n";
	$dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
	get_obs_at_hr_q($valid_time,$dbh);
	$dbh->disconnect();

#if($n_stations_loaded > 0) {
    $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
    foreach my $region (@regions) {
	#print "GENERATING SUMMARIES for $data_source,$valid_time,$fcst_len,$region\n\n";
	update_summaries_v2($data_source,$valid_time,$fcst_len,$region,$dbh,$db_name,1);
    }
    update_summaries_vgtyp($data_source,$valid_time,$fcst_len,$dbh,$db_name,1);
   $dbh->disconnect();
#} else {
    print "NOT GENERATING SUMMARIES\n\n";
#}
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
select N_drh from surface_sums.${data_source}_metar_v2_${region}
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


