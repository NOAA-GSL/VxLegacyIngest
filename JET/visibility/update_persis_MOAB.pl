#!/usr/bin/perl
#
#PBS -d .                                                                                                           
#PBS -N vis_persis                                                                                                
#PBS -A amb-verif                                                                                                       
#PBS -l procs=1                                                                                                     
#PBS -l partition=xjet                                                                                              
#PBS -q service                                                                                                     
#PBS -l walltime=01:00:00                                                                                           
#PBS -l vmem=1G                                                                                                     
#PBS -e tmp/                                                                                                        
#PBS -o tmp/
#
use strict;

# PREAMBLE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
my $thisDir = $ENV{PBS_O_WORKDIR};
unless($thisDir) {
    # we've been called locally instead of qsubbed
    use File::Basename; 
    my ($basename,$thisDir2) = fileparse($0);
    $thisDir = $thisDir2;
}

my $DEBUG=1;  # MAKE THIS NON-ZERO TO PRODUCE EXTRA DEBUG PRINTOUT


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
require "./set_connection.pl";
# re-set the db
$ENV{DBI_DSN} = "DBI:mysql:visibility_sums2:wolphin";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $query = "";

my $hrs_ago = abs($ARGV[0]);
my $time = time();
my $this_hour = $time - $time%3600;
my $valid_time = $this_hour - $hrs_ago*3600;
print "updating persistence fcsts valid at ".gmtime($valid_time)."\n";

foreach my $model qw(persis) {
foreach my $thresh qw(50 100 300 500 1000) {
foreach my $fcst_len (0,1,2,3,6,9,12) {
    my $fcst_len_str = "";
    if($fcst_len > 0) {
	$fcst_len_str = "- $fcst_len*3600";
    }
    my @regions = qw(RUC GtLk E_US AK);
    if($model =~ /^RR/) {
	@regions = qw(RUC GtLk E_US RR AK);
    }
foreach my $region (@regions)  {
    my $table = "${model}_$region";
    my $table_list = "ceiling.metars,visibility.obs as ob,visibility.obs as o1";
    my $ruc_domain_string = "";
    # ORDER IS FORECAST, OBSERVATION!!
    # in the RUC region, we need to be special
    if($region eq "RUC") {
	$table_list .=",ceiling.ruc_metars as rm";
	$ruc_domain_string = "and ob.madis_id = rm.madis_id";
    }
    $query = qq[
replace into $table (time,fcst_len,trsh,yy,yn,ny,nn)
select 1*3600*floor((ob.time+1800)/(1*3600)) as time,
 $fcst_len as fcst_len,
 $thresh as trsh,
 sum(if(    (o1.vis100 < $thresh) and     (ob.vis100 < $thresh),1,0)) as yy,
 sum(if(    (o1.vis100 < $thresh) and NOT (ob.vis100 < $thresh),1,0)) as yn,
 sum(if(NOT (o1.vis100 < $thresh) and     (ob.vis100 < $thresh),1,0)) as ny,
 sum(if(NOT (o1.vis100 < $thresh) and NOT (ob.vis100 < $thresh),1,0)) as nn
from
$table_list
where 1 = 1
and ob.madis_id = metars.madis_id
and ob.madis_id = o1.madis_id
# assume each metar arrives at the same time during the hour
# (need to check this!)
and o1.time = ob.time $fcst_len_str
$ruc_domain_string];
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
    } elsif($region eq "AK") {
	$query .= qq[
# Alaska region (with some of Canada)
and lat > 5300 and lat < 7200
and lon > -17000 and lon < -12900];
    } else {
	# compare everything -- no where clause
    }

    $query .= qq[
and ob.time  >= $valid_time - 1800
and ob.time < $valid_time + 1800
# shouldn't need the two lines below, but they speed up the query
# by a factor of > 10! (not obvious from the 'explain' output)
and o1.time  >= $valid_time - 1800 $fcst_len_str
and o1.time < $valid_time + 1800 $fcst_len_str	 
group by time
having yy+yn+ny+nn > 0
order by time];

    if($DEBUG) {
	print "$query;\n";
    }
    $dbh->do($query);

}}}}

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
    if(-M $file > .01) {
	print "unlinking $file\n";
	unlink "$file" || print "Can't unlink $file $!\n";
    }
}
closedir DIR;
print "NORMAL TERMINATION\n";
