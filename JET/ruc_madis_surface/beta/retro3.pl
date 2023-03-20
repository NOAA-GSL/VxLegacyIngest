#!/usr/bin/perl
#
#  Set the name of the job.
#$ -N surf_drvr5
#  Make sure that the .e and .o file arrive in the working directory
#$ -cwd
#
#  Set the account
#$ -A amb-verif
#
#  Ask for 1 cpus of type service
#$ -pe service 1
#
#  My code is re-runnable
#$ -r y
#
# send mail on abort, end
#$ -m a
#$ -M verif-amb.gsd@noaa.gov
#
#  The max walltime 
#$ -l h_rt=01:00:00
#
#$ -e tmp/
#$ -o /dev/null
#
use strict;
my $DEBUG=1;
#
# set up to call locally (from the command prompt)
my $thisDir = $ENV{SGE_O_WORKDIR};
my $qsubbed=1;
unless($thisDir) {
    # we've been called locally instead of qsubbed
    $qsubbed=0;
    use File::Basename; 
    my ($basename,$thisDir2) = fileparse($0);
    $thisDir = $thisDir2;
}
my $output_id = $ENV{JOB_ID} || $$;

#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";
$thisDir = $ENV{PWD};

use Time::Local;
use DBI;

$|=1;  #force flush of buffers after each print
open (STDERR, ">&STDOUT") || die "can't dup stdout ($!)\n";
$ENV{'PATH'}="/bin";
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
my $rh_flag = 0;

use lib "./";
#require "timelocal.pl";   #includes 'timegm' for calculations in gmt
require "./jy2mdy.pl";
require "./update_summaries_retro5.pl";
require "./update_summaries_retro.pl";
require "./get_grid3.pl";


my $data_source = $ARGV[0];
my $startSecs = $ARGV[1];
my $endSecs = $ARGV[2];
my $reprocess=0;
if(defined $ARGV[3] && $ARGV[3] > 0) {
    $reprocess=1;
}
$ENV{DBI_DSN} = "DBI:mysql:madis3:wolphin.fsl.noaa.gov";
$ENV{DBI_USER} = "sfc_retro";
$ENV{DBI_PASS} = "EricHaidao";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $query;
if($qsubbed == 1) {
    my $output_file = "tmp/$data_source.sfc_dr5.out.$output_id";
# send standard out (and stderr) to $output_File
    use IO::Handle;
    *STDERR = *STDOUT;		# send standard error to standard out
    open OUTPUT, '>',"$output_file" or die $!;
    STDOUT->fdopen( \*OUTPUT, 'w' ) or die $!; # send stdout to output file
}
# see if we should use the obs_retro table for obs
my @res = $dbh->selectrow_array("select max(time) from obs_retro");
my $max_retro_secs = $res[0];
print "max retro secs is $max_retro_secs\n";

my $db_machine = "wolphin.fsl.noaa.gov";
my $db_name = "madis3";
# the files below aren't used, but could be used
# IF we go back to using 'load data local infile'
# (they're in the argument list to the executables, even though they're not used
# currently by the WRF (HRRR) executables)
my $tmp_file = "tmp/${data_source}.$$.tmp";
my $data_file = "tmp/${data_source}.$$.data";
my $data_1f_file = "tmp/${data_source}.$$.data_1f";
my $coastal_file = "tmp/${data_source}.$$.coastal";
my $coastal_station_file = "tmp/${data_source}.$$.coastal_stations";

my @regions;
my @fcst_lens;
my $WRF;
@regions = qw[ALL_RR1 ALL_RUC E_RUC W_RUC ALL_HRRR E_HRRR W_HRRR NORTHWEST];
#@regions = qw[ALL_RUC];
@fcst_lens = (1,0,3,6,9,12);
#@fcst_lens = (1);

# see if the needed tables exist
$dbh->do("use madis3");
#$query = qq(show tables like "$data_source%");
#xue updated this one from zeus version on 20140513
$query = qq(show tables like "${data_source}p");

my $result = $dbh->selectrow_array($query);
unless($result) {
    # create needed tables
    $query = "create table madis3.${data_source}p like madis3.retro_template";
    $dbh->do($query);
    $query = "create table madis3.${data_source}p1f like madis3.retro_template_1f";
    $dbh->do($query);
    $query = "create table madis3.${data_source}_coastal5 like madis3.retro_template_coastal5";
    $dbh->do($query);
    $query = "create table madis3.stations_${data_source}_coastal5 ".
	"like madis3.retro_template_stations_coastal5";
    $dbh->do($query);
    $dbh->do("use surface_sums");
    foreach my $fcst_len (@fcst_lens) {
	foreach my $region (@regions) {
	    my $table = "${data_source}_${fcst_len}_metar_${region}";
	    $query = qq[create table $table like template];
	    print "$query\n";
	    $dbh->do($query);
	}
    }
    $dbh->do("use surface_sums2");
    foreach my $region (@regions) {
        my $table = "${data_source}_metar_v2_${region}";
        $query = qq[create table $table like template];
        print "$query\n";
        $dbh->do($query);
    }
}

$WRF=1;
#for(my $valid_time=$startSecs;$valid_time<=$endSecs;$valid_time+=3*3600) {
for(my $valid_time=$startSecs;$valid_time<=$endSecs;$valid_time+=1*3600) {
foreach my $fcst_len (@fcst_lens) {
my $valid_str = gmtime($valid_time);
my $run_time = $valid_time - $fcst_len * 3600;
my $valid_date = sql_datetime($valid_time);
my ($dym,$dym,$hour,$mday,$month,$year,$wday,$yday) =
    gmtime($run_time);
my $jday=$yday+1;

if($reprocess == 0 &&
   already_processed($data_source,$valid_time,$fcst_len,$regions[0],$DEBUG)) {
    print "\nALREADY LOADED: $data_source $fcst_len h fcst valid at $valid_str\n";
    next;
} else {
    print "\nTO PROCESS: $fcst_len h fcst valid at $valid_str\n";
}

my $start = "";			# not looking for 'latest'

my $dir = sprintf("RR_retro/$data_source/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
my $base_file;
if($fcst_len == 0) {
    $base_file = sprintf("wrfprs_rr_%02d.al00.grb2",$fcst_len);
} else {
    $base_file = sprintf("wrfprs_rr_%02d.grib2",$fcst_len);
}
$file = "$dir/$base_file";

my($run_year,$run_month_num,$run_mday,$run_hour,$run_fcst_len);

unless(-r $file) {
    print "file $file not found for $data_source $fcst_len h fcst valid at $valid_str.\n";
    next;
} else {
    print "FILE FOUND $data_source $fcst_len h fcst valid at $valid_str\n";
}
# get grid details
my($la1,$lo1,$lov,$latin1,$nx,$ny,$dx,$grib_type,$grid_type,$valid_date_from_file,$fcst_proj)
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
my $arg_unsafe;
if($grib_type == 2 && $WRF == 1) {
    $arg_unsafe = "${thisDir}/WRF_retro.x ".
	"$data_source $valid_time $file $grib_type $grid_type $fcst_len ".
	"$la1 $lo1 $lov $latin1 $dx ".
	"$nx $ny 1 $max_retro_secs ".
	"$tmp_file $data_file $data_1f_file $coastal_file $coastal_station_file ".
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
    $arg_unsafe = "${thisDir}/agrib_madis_sites.x $db_machine $db_name ".
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
    
} elsif($grib_type != 2) {
    die "cannot do grib1 files, use retro.pl for that!!\n";
}    
if($n_stations_loaded > 0) {
    foreach my $region (@regions) {
	my $valid_time_string = gmtime($valid_time);
	print "GENERATING SUMMARIES for $data_source,$valid_time_string,$fcst_len,$region\n";
	update_summaries_retro5($data_source,$valid_time,$fcst_len,$region,
				$max_retro_secs,$dbh,$db_name,0);
	update_summaries_retro($data_source,$valid_time,$fcst_len,$region,
				$max_retro_secs,$dbh,$db_name,0);
    }
} else {
    print "NOT GENERATING SUMMARIES\n\n";
}
}}

#finish up
$dbh->disconnect();

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
    my $query =<<"EOI"
select count(*) from surface_sums.${data_source}_${fcst_len}_metar_${region}
where valid_day = $desired_valid_day and hour = $desired_hour
EOI
;
    #if($DEBUG) {print "query is $query\n";}
    my $sth = $dbh->prepare($query);
    $sth->execute();
    my($n);
    $sth->bind_columns(\$n);
    $sth->fetch();
    $sth->finish();
    # for debugging:
    #$n=0;
    #print "n returned is $n\n";
    return $n;
}


