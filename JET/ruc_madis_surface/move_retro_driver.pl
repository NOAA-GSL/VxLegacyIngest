#!/usr/bin/perl
#PBS -d .                                                                                                           
#PBS -N move_retro_driver                                                                                                
#PBS -A amb-verif                                                                                                       
#PBS -l procs=1                                                                                                     
#PBS -l partition=tjet:ujet:sjet:vjet:xjet                                                                                              
#PBS -q service                                                                                                     
#PBS -l walltime=09:00:00                                                                                           
#PBS -l vmem=1G                                                                                                     
#PBS -M verif-amb.gsd@noaa.gov
#PBS -m a
#PBS -e tmp/                                                                                                        
#PBS -o tmp/
#
#
use strict;
my $thisDir = $ENV{PBS_O_WORKDIR};
unless($thisDir) {
    # we've been called locally instead of qsubbed
    use File::Basename; 
    my ($basename,$thisDir2) = fileparse($0);
    $thisDir = $thisDir2;
}
my $DEBUG=1;
use Time::Local;
use DBI;

$|=1;  #force flush of buffers after each print
open (STDERR, ">&STDOUT") || die "can't dup stdout ($!)\n";
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


#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";

use lib "./";
use Time::Local;
#require "timelocal.pl";   #includes 'timegm' for calculations in gmt
require "./jy2mdy.pl";
require "./move_summaries_retro.pl";
require "./set_connection3.pl";

my $usage = "usage: $0 model\n";
if (@ARGV < 1) {
    print "too few args. Exiting.\n";
    exit;
}

my $i_arg=0;
my $data_source = $ARGV[$i_arg++];

# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});

my $query =<<"EOI"
select min(valid_day) from surface_sums.${data_source}_0_metar_ALL_HRRR where valid_day > 10 
EOI
;

my @start_time = $dbh->selectrow_array($query); 
my $start_time = @start_time[0];

$query =<<"EOI"
select max(valid_day) from surface_sums.${data_source}_0_metar_ALL_HRRR where valid_day > 10
EOI
;

my @end_time = $dbh->selectrow_array($query); 
my $end_time = @end_time[0];

print "start_time: $start_time\n";
print "end_time: $end_time\n";
$dbh->disconnect();

my $interval_hours = 1;

# get list of valid_dates on hour boundary
my $time = $start_time;
my @valid_times = ();

while ($time <= $end_time) {
   push @valid_times, $time;
   $time+=$interval_hours*3600;
}

print "valid_times: @valid_times\n";

for my $valid_time (@valid_times) {
   my $current_time = time();
   print "####\n";
   print "current time: $current_time\n";
   move_summaries($data_source,$valid_time);
}
