#!/usr/bin/perl
#
# THIS USES A NEW PER-MODEL STRUCTURE FOR THE SOUNDINGS TABLE(S)
#
#PBS -d .
#PBS -N sfc_vgtyp
#PBS -A amb-verif
#PBS -l procs=1
#PBS -l partition=vjet
#PBS -q service 
#PBS -l walltime=02:00:00
#PBS -l vmem=1G
#PBS -M verif-amb.gsd@noaa.gov
#PBS -m a
#PBS -e tmp/
#PBS -o tmp/
#
use strict;
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
my $valid_str;
my $rh_flag = 0;		# 1 if the rh variable is SPFH, 0 if it is RH

use lib "./";
use Time::Local;    #includes 'timegm' for calculations in gmt
require "./jy2mdy.pl";
require "./update_summaries_vgtyp_1h.pl";
require "./get_obs_at_hr_q.pl";
require "./get_grid.pl";

# connect to the database
$ENV{DBI_DSN} = "DBI:mysql:madis3:wolphin.fsl.noaa.gov";
$ENV{DBI_USER} = "sfc_driver5";
$ENV{DBI_PASS} = "driver5";
my $dbh;

my $reprocess=0;
my $i_arg=0;
my @data_sources = qw(HRRR RR1h);

if($qsubbed == 1) {
    my $output_file = "tmp/update_vgtyp.out.$output_id";
# send standard out (and stderr) to $output_File
    use IO::Handle;
    *STDERR = *STDOUT;		# send standard error to standard out
    open OUTPUT, '>',"$output_file" or die $!;
    STDOUT->fdopen( \*OUTPUT, 'w' ) or die $!; # send stdout to output file
}

my $db_machine = "wolphin.fsl.noaa.gov";
my $db_name = "madis3";

my $last_vt =  1493020800;     # 8Z 24 april 2017 
my $first_vt = 1488412800 ;

my @fcst_lens = (1);
my $now = time();

for (my $valid_time=$last_vt;$valid_time >= $first_vt; $valid_time -= 3600) {
$valid_str = gmtime($valid_time);
foreach my $data_source (@data_sources) {
foreach $fcst_len (@fcst_lens) {
my $valid_date = sql_datetime($valid_time);
$dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
get_obs_at_hr_q($valid_time,$dbh);

update_summaries_vgtyp_1h($data_source,$valid_time,$fcst_len,$dbh,$db_name,1);
}
}
# drop old hr_obs tables not otherwise needed.
if($now - $valid_time > 24*3600) {
    my $query = qq{drop table if exists hr_obs_$valid_time};
    print "$query;\n";
    $dbh->do($query);
}
}

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

