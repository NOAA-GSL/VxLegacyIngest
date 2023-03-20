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
use lib "./";
use Time::Local;    #includes 'timegm' for calculations in gmt
require "./update_persis_v2.pl";
require "./get_obs_at_hr_q.pl";
require "./get_grid.pl"; # needed for sql_dattime

my $data_source = "persis";
# connect to the database
$ENV{DBI_DSN} = "DBI:mysql:madis3:wolphin.fsl.noaa.gov";
$ENV{DBI_USER} = "sfc_driver5";
$ENV{DBI_PASS} = "driver5";
my $dbh;
my $reprocess=0;
my $i_arg=0;
my $hours_ago = abs($ARGV[$i_arg++]);
if(defined $ARGV[$i_arg] && $ARGV[$i_arg] > 0) {
    $reprocess=1;
}
if($qsubbed == 1) {
    my $output_file = "tmp/$data_source.sfc_drq.$output_id.out";
    
# send standard out (and stderr) to $output_File
    use IO::Handle;
    *STDERR = *STDOUT;		# send standard error to standard out
    open OUTPUT, '>',"$output_file" or die $!;
    STDOUT->fdopen( \*OUTPUT, 'w' ) or die $!; # send stdout to output file
}

my $db_name = "madis3";
my $time = time();
# get on hour boundary
$time = $time - $time%3600 - $hours_ago*3600;
my @valid_times = ($time,$time-1*3600,$time-2*3600,$time-3*3600,$time-6*3600,$time-9*3600);
my @regions = qw[ALL_RR1 ALL_RUC E_RUC W_RUC ALL_HRRR E_HRRR W_HRRR AK HWT STMAS_CI];
my @fcst_lens = (1,2,3,6,9,12);

$dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
$dbh->do("use $db_name");

foreach my $fcst_len (@fcst_lens) {
foreach my $valid_time (@valid_times) {
my $valid_str = gmtime($valid_time);
my $run_time = $valid_time - $fcst_len * 3600;
my $valid_date = sql_datetime($valid_time);

if($reprocess == 0 &&
   already_processed($data_source,$valid_time,$fcst_len,$regions[0],$DEBUG)) {
    print "\nALREADY LOADED: $data_source $fcst_len h fcst valid at $valid_str\n";
    next;
} else {
    print "\nTO PROCESS: $fcst_len h fcst valid at $valid_str\n";
    foreach my $region (@regions) {
	update_persis_v2($valid_time,$fcst_len,$region,$dbh,$db_name,$DEBUG);
    }
}
}}

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
