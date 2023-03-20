#!/usr/bin/perl
#
#  Set the name of the job.
#$ -N HRRR_madis
#  Make sure that the .e and .o file arrive in the working directory
#$ -cwd
#
#  Set the account
#$ -A wrfruc
#
#  Ask for 1 cpus of type service
#$ -pe service 1
#
#  My code is re-runnable
#$ -r y
#
# send mail on abort, end
#$ -m a
#$ -M William.R.Moninger@noaa.gov
#
#  The max walltime 
#$ -l h_rt=01:00:00
#
#$ -e tmp/
#$ -o tmp/
#
use strict;
my $thisDir = $ENV{SGE_O_WORKDIR};
unless($thisDir) {
    # we've been called locally instead of qsubbed
    use File::Basename; 
    my ($basename,$thisDir2) = fileparse($0);
    $thisDir = $thisDir2;
}
my $DEBUG=1;
#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";
$thisDir = $ENV{PWD};

#useful DEBUGGING info vvvvvvvvvvvvvv
if($DEBUG) {
    foreach my $key (sort keys(%ENV)) {
        print "$key: $ENV{$key}\n";
    }
    print "thisDir is $thisDir\n";
    print "\n";
}
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


use lib "./";
#require "timelocal.pl";   #includes 'timegm' for calculations in gmt
require "./get_iso_file3.pl";
require "./jy2mdy.pl";
require "./update_summaries2.pl";
require "./get_grid.pl";

require "./set_connection3.pl";
# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});

my $hours_ago = abs($ARGV[0]);
print "hours_ago is $hours_ago\n";
my $time = time();
# get on hour boundary
$time = $time - $time%3600 - $hours_ago*3600;
my @valid_times = ($time,$time-1*3600,$time-3*3600,$time-8*3600);
#my @valid_times = ($time);

foreach my $data_source (qw(HRRR)) {
foreach $fcst_len ((0,1,3,6,9,12)) {
#foreach $fcst_len ((0)) {
foreach my $valid_time (@valid_times) {
my $valid_str = gmtime($valid_time);
my $run_time = $valid_time - $fcst_len * 3600;

if(already_processed($data_source,$valid_time,$fcst_len,$DEBUG)) {
    print "\nALREADY LOADED: $data_source $fcst_len h fcst valid at $valid_str\n";
    next;
} else {
    #print "\nTO PROCESS: $fcst_len h fcst valid at $valid_str\n";
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
my($la1,$lo1,$lov,$latin1,$nx,$ny,$dx,$grib_type,$grid_type,$valid_date,$fcst_proj,$wind_rot_flag)
    = get_grid($file,$thisDir,$DEBUG);
my($valid_year,$valid_month_num,$valid_mday,$valid_hour) = $valid_date =~ /(....)(..)(..)(..)/;
if(1) {
    print "|$la1| |$lo1| |$lov| |$latin1| ".
	"|$nx| |$ny| |$dx|\n";
    print ("valid times from get_grid: $valid_year,$valid_month_num,$valid_mday,".
	   "$valid_hour,$fcst_proj\n");
}
my $valid_time_from_file = timegm(0,0,$valid_hour,$valid_mday,
				  $valid_month_num - 1,
				  $valid_year);
if($valid_time_from_file != $valid_time) {
    print "BAD VALID TIME from file: $valid_time_from_file\n";
    exit(1);
}
if($grib_type == 1) {
    my $arg_unsafe = "${thisDir}/surface_HRRR.x ".
	"$data_source $valid_time $file $fcst_len ".
	"$la1 $lo1 $lov $latin1 $dx ".
	"$nx $ny 1 $DEBUG";
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
} elsif($grib_type == 2) {
    die "cannot do grib2 files yet!!\n";
}
if($n_stations_loaded > 0) {
    foreach my $region (qw[RUC E_RUC W_RUC]) {
	update_summaries2($data_source,$valid_time,$fcst_len,$region,$dbh,$DEBUG);
    }
} else {
    print "NOT GENERATING SUMMARIES\n\n";
}
}}}

sub already_processed($data_source,$valid_time,$fcst_len,$DEBUG) {
    my ($data_source,$valid_time,$fcst_len,$DEBUG) = @_;
    my $sec_of_day = $valid_time%(24*3600);
    my $desired_hour = $sec_of_day/3600;
    my $desired_valid_day = $valid_time - $sec_of_day;
    my $query =<<"EOI"
select count(*) from surface_sums.${data_source}_${fcst_len}_metar_RUC
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
    #print "n returned is $n\n";
    return $n;
}


