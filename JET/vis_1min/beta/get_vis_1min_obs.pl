#!/usr/bin/perl
#PBS -d .
#PBS -N vis_1min_obs
#PBS -A amb-verif
#PBS -l procs=1
#PBS -l partition=vjet
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
use CGI;
use DBI;

my $current_secs = time();
# valid secs is start of current hour
# or n_hours back (in ARGV[0])
# or ARGV[0]  could be a calendar time
my $time;
if($ARGV[0] > 315532800) { # 1-Jan-1980
    $time = $ARGV[0];
} else {
    $time = $current_secs - $current_secs%3600 - abs($ARGV[0])*3600;
}

#connect
$ENV{DBI_DSN} = "DBI:mysql:vis_1min:wolphin.fsl.noaa.gov";
$ENV{DBI_USER} = "wcron0_user";
$ENV{DBI_PASS} = "cohen_lee";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $query = "";
my $sth;
my $window_half_width = 5;	# half-width of window in minutes

$query =<<"EOI"
replace into vis_1min.obs (madis_id,N,valid_time,vis_min,vis_avg,vis_closest,vis_std)
values (?,?,?,?,?,?,?)
EOI
    ;
my $sth_load = $dbh->prepare($query);

my @valid_times = ($time,$time-(0.75*3600),$time-(0.5*3600),$time-(.25*3600));

foreach my $valid_secs (@valid_times) {

my $time_str = gmtime($valid_secs);
my $current_time_str = gmtime(time());
print "$valid_secs ($time_str), hrs_ago: $ARGV[0]. run at $current_time_str\n";

$query =<<"EOI"
 select sta_id
,count(*) as N
,$valid_secs 
,min(vis100) as vis_min
,round(avg(vis100),0) as vis_avg
,round(std(vis100),0) as vis_std
,group_concat(vis100 order by abs($valid_secs - time)) as vis_closest
from 1min_asos.obs
where 1=1
and time >=  $valid_secs- $window_half_width*60
and time <=  $valid_secs + $window_half_width*60
group by sta_id
order by vis_std desc
EOI
;
if($DEBUG) {print "$query;\n";}
my $sth = $dbh->prepare($query);
$sth->execute();
my($madis_id,$N,$valid_time,$vis_min,$vis_avg,$vis_std,$vis_closest_str);
$sth->bind_columns(\$madis_id,\$N,\$valid_time,\$vis_min,\$vis_avg,\$vis_std,\$vis_closest_str);
my $count=0;
my $vis_count=0;
my $vis_out;
while($sth->fetch()) {
    $count++;
    if($vis_min) {
	$vis_count++;
	my @vis_closest = split(/,/,$vis_closest_str);
	#print "$madis_id,$N,$valid_time,$vis_min,$vis_avg,$vis_std,$vis_closest[0], |$vis_closest_str|\n";
	$sth_load->execute($madis_id,$N,$valid_time,$vis_min,$vis_avg,$vis_closest[0],$vis_std);
    }
}
print "$count metars world-wide ($vis_count with vis) stored for valid hour $time_str run at $current_time_str \n\n";
$sth->finish();
}
$dbh->disconnect();


# clean up tmp directory
require "./clean_tmp_dir.pl";
clean_tmp_dir();

