#!/usr/bin/perl
#PBS -d .                                                                                                           
#PBS -N ceil_5min_persis                                                                                                
#PBS -A amb-verif                                                                                                      
#PBS -l procs=1                                                                                                     
#PBS -l partition=tjet:ujet:sjet:vjet:xjet                                                                                             
#PBS -q service                                                                                                     
#PBS -l walltime=01:00:00                                                                                           
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

# PREAMBLE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

my $DEBUG=0;  # MAKE THIS NON-ZERO TO PRODUCE EXTRA DEBUG PRINTOUT

#for security, must set the PATH explicitly
$ENV{PATH}="";
 
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
# end useful DEBUGGING info ^^^^^^^^^^^^^^^^^
# END PREAMBLE^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

$ENV{'TZ'}="GMT";
use DBI;
#connect
$ENV{DBI_DSN} = "DBI:mysql:vis_5min_sums:wolphin";
$ENV{DBI_USER} = "wcron0_user";
$ENV{DBI_PASS} = "cohen_lee";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $query = "";

my $hrs_ago = abs($ARGV[0]);
my $time = time();
my $this_hour = $time - $time%3600;
my $vtime = $this_hour - $hrs_ago*3600;
my @valid_times = ($vtime,$vtime-15*60,$vtime-30*60,$vtime-45*60);
my @fcst_len_mins = ();
for(my $min=0;$min<=6*60;$min+=15) {
    push(@fcst_len_mins,$min);
}

foreach my $valid_time (@valid_times) {
foreach my $model qw(persis) {
foreach my $thresh qw(50 100 300 500 1000) {
#foreach my $thresh qw(6000) {
foreach my $fcst_len_min (@fcst_len_mins) {
    my $fcst_len_hr = int($fcst_len_min/60);
    my $fcst_len_inc_min = $fcst_len_min - 60*$fcst_len_hr;
    my @regions = qw(E_US GtLk);
foreach my $region (@regions)  {
    my $table = "${model}_$region";
    my $table_list = "metars_5min.metars,vis_5min.obs as ob,vis_5min.obs as o1";
    # ORDER IS FORECAST, OBSERVATION!!
    $query = qq[
replace into $table (time,fcst_len,fcst_min,trsh,yy,yn,ny,nn)
select 1*900*floor((ob.time+450)/(1*900)) as time,
 $fcst_len_hr as fcst_len,
 $fcst_len_inc_min as fcst_min,
 $thresh as trsh,
 sum(if(        (o1.vis100 < $thresh) and         (ob.vis100 < $thresh),1,0)) as yy,
 sum(if(        (o1.vis100 < $thresh) and NOT (ob.vis100 < $thresh),1,0)) as yn,
 sum(if(NOT (o1.vis100 < $thresh) and         (ob.vis100 < $thresh),1,0)) as ny,
 sum(if(NOT (o1.vis100 < $thresh) and NOT (ob.vis100 < $thresh),1,0)) as nn
from
$table_list
where 1 = 1
and ob.madis_id = o1.madis_id
and ob.madis_id = metars.madis_id
and o1.time = ob.time - $fcst_len_min*60];
    if($region eq "GtLk") {
	$query .= qq[
# Great Lakes region (approx)
and lat >= 3800 and lat <= 4900
and lon >= -9900 and lon <= -7900];
    } elsif($region eq "E_US") {
	$query .= qq[
# larger region for Chautauqua
and lat > 2800 and lat < 4900
and lon > -10200 and lon < -7000];
    }
    $query .= qq[
and ob.time  >= $valid_time - 450
and ob.time < $valid_time + 450
# shouldn't need the two lines below, but they speed up the query
# by a factor of > 10! (not obvious from the 'explain' output)
and o1.time  >= $valid_time - 450 - $fcst_len_min*60
and o1.time < $valid_time + 450 - $fcst_len_min*60
group by time
having yy+yn+ny+nn > 50  # avoid spurious times with too few metars
order by time];

    if($DEBUG) {
	print "$query;\n";
    }
    my $rows = $dbh->do($query);
    my $time_str = gmtime($valid_time);
    print "updating $table for threh $thresh, ${fcst_len_hr}h ${fcst_len_inc_min}m fcst, $time_str. $rows rows affected\n";
}}}}}

$dbh->disconnect();
print "NORMAL TERMINATION\n";

# clean up tmp directory
require "./clean_tmp_dir.pl";
clean_tmp_dir();
