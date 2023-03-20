#!/usr/bin/perl
#SBATCH -J vis_1min_persis
#SBATCH --mail-user=verif-amb.gsl@noaa.gov                                                                                          
#SBATCH --mail-type=FAIL
#SBATCH -A amb-verif
#SBATCH -n 1
#SBATCH -p service 
#SBATCH -t 01:00:00
#SBATCH --mem=1G
#SBATCH -D .
#SBATCH -e /home/amb-verif/vis_1min/tmp/vis_1min_persis.e%j
#SBATCH -o /home/amb-verif/vis_1min/tmp/vis_1min_persis.o%j
#
#
use strict;
my $thisDir = $ENV{SLURM_SUBMIT_DIR};
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
$ENV{DBI_DSN} = "DBI:mysql:vis_1min_sums:wolphin";
$ENV{DBI_USER} = "wcron0_user";
$ENV{DBI_PASS} = "cohen_lee";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $query = "";
my $VIS_STD_LIMIT = 240; # approx mean + 3 std for vis_std, for those obs with some limited vis in the 10 min window
my @truths = qw(qc min closest avg);
my $hrs_ago = abs($ARGV[0]);
my $time = time();
my $this_hour = $time - $time%3600;
my $vtime = $this_hour - $hrs_ago*3600;
my @valid_times = ($vtime ,$vtime-15*60,$vtime-30*60,$vtime-45*60);
my @fcst_len_mins = ();
for(my $min=0;$min<=6*60;$min+=15) {
    push(@fcst_len_mins,$min);
}
#@fcst_len_mins = (60);

foreach my $valid_time (@valid_times) {
foreach my $model qw(persis) {
foreach my $thresh qw(50 100 300 500 1000) {
#foreach my $thresh qw(6000) {
foreach my $fcst_len_min (@fcst_len_mins) {
    my $fcst_len_hr = int($fcst_len_min/60);
    my $fcst_len_inc_min = $fcst_len_min - 60*$fcst_len_hr;
    my @regions = qw(ALL_HRRR E_HRRR W_HRRR E_US);
foreach my $region (@regions)  {
    my $table = "${model}_$region";
    my $table_list = "1min_asos.metars as m,vis_1min.obs as ob,vis_1min.obs as o1";
    foreach my $truth (@truths) {
    # ORDER IS FORECAST, OBSERVATION!!
    $query = qq[
replace into $table (time,fcst_len,fcst_min,trsh,truth,yy,yn,ny,nn)
select ob.valid_time as time,
 $fcst_len_hr as fcst_len,
 $fcst_len_inc_min as fcst_min,
 $thresh as trsh,
 '$truth' as truth,];
    if($truth ne "qc") {
	$query .= qq[
 sum(if(        (o1.vis_$truth < $thresh) and         (ob.vis_$truth < $thresh),1,0)) as yy,
 sum(if(        (o1.vis_$truth < $thresh) and NOT (ob.vis_$truth < $thresh),1,0)) as yn,
 sum(if(NOT (o1.vis_$truth < $thresh) and         (ob.vis_$truth < $thresh),1,0)) as ny,
 sum(if(NOT (o1.vis_$truth < $thresh) and NOT (ob.vis_$truth < $thresh),1,0)) as nn];
    } else {
	$query .= qq[
 sum(if(        (o1.vis_closest < $thresh) and         (ob.vis_closest < $thresh),1,0)) as yy,
 sum(if(        (o1.vis_closest < $thresh) and NOT (ob.vis_closest < $thresh),1,0)) as yn,
 sum(if(NOT (o1.vis_closest < $thresh) and         (ob.vis_closest < $thresh),1,0)) as ny,
 sum(if(NOT (o1.vis_closest < $thresh) and NOT (ob.vis_closest < $thresh),1,0)) as nn];
    }
    $query .= qq[
from
$table_list
where 1 = 1
and ob.madis_id = o1.madis_id
and ob.madis_id = m.madis_id
and o1.valid_time = ob.valid_time - $fcst_len_min*60
and ob.valid_time  = $valid_time
# shouldn't need the two lines below, but they speed up the query
# by a factor of > 10! (not obvious from the 'explain' output)
and o1.valid_time  = $valid_time - $fcst_len_min*60];
    if($truth eq "qc") {
    $query .= qq[
and ob.vis_std < $VIS_STD_LIMIT];
}
    if($region eq "E_US") {
	$query .= qq[
# larger region for Chautauqua
and lat > 2800 and lat < 4900
and lon > -10200 and lon < -7000];
     } else {
	$query .= qq[
and find_in_set('$region',m.reg)];
    }
    $query .= qq[
group by time
having yy+yn+ny+nn > 50  # avoid spurious times with too few metars
order by time];

    if(1) {
	print "$query;\n";
    }
    my $rows = $dbh->do($query);
    my $time_str = gmtime($valid_time);
    print "updating $table for threh $thresh, ${fcst_len_hr}h ${fcst_len_inc_min}m fcst, $time_str. $rows rows affected\n";
    }}}}}}

$dbh->disconnect();
print "NORMAL TERMINATION\n";

# clean up tmp directory
require "./clean_tmp_dir.pl";
clean_tmp_dir();