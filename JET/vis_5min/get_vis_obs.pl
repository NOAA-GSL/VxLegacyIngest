#!/usr/bin/perl
#SBATCH -J vis_5min_obs
#SBATCH --mail-user=verif-amb.gsl@noaa.gov                                                                                          
#SBATCH --mail-type=FAIL
#SBATCH -A amb-verif
#SBATCH -n 1
#SBATCH -p service 
#SBATCH -t 01:00:00
#SBATCH --mem=1G
#SBATCH -D .
#SBATCH -e /home/amb-verif/vis_5min/tmp/vis_5min_obs.e%j
#SBATCH -o /home/amb-verif/vis_5min/tmp/vis_5min_obs.o%j
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
my $vis100;

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

my @valid_times = ($time,$time-(0.75*3600),$time-(0.5*3600),$time-(.25*3600));

foreach my $valid_secs (@valid_times) {
#connect
my $db_machine = $ARGV[1] || "wolphin.fsl.noaa.gov";
my $db = "metars_5min";
$ENV{DBI_DSN} = "DBI:mysql:vis_5min:$db_machine";
$ENV{DBI_USER} = "wcron0_user";
$ENV{DBI_PASS} = "cohen_lee";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $query = "";
my $sth;

my $time_str = gmtime($valid_secs);
my $current_time_str = gmtime(time());
print "$valid_secs ($time_str), hrs_ago: $ARGV[0]. run at $current_time_str\n";

$query =<<"EOI"
replace into obs values(?,?,?)
EOI
    ;
my $sth_load_vis = $dbh->prepare($query);

$query=<<"EOI"
delete from obs
where madis_id = ?
and time != ?
and time >= ?
and time < ?
EOI
    ;
my $sth_clean_vis = $dbh->prepare($query);

$query =<<"EOI"
create temporary table x1
(UNIQUE id_time (sta_id,time))
ENGINE = MEMORY
select sta_id,time,loc_id,vis100
from $db.obs where 1=1
and obs.time >= $valid_secs - 450
and obs.time < $valid_secs + 450
EOI
    ;
if($DEBUG) {print "$query;\n";}
$dbh->do($query);

$query =<<"EOI"
create temporary table x2
(index (sta_id,loc_id,min_dif))
ENGINE = MEMORY
select sta_id,loc_id,min(cast(abs(time - $valid_secs) as signed)) as min_dif
from x1
group by sta_id,loc_id
EOI
    ;
if($DEBUG) {print "$query;\n";}
$dbh->do($query);

$query =<<"EOI"
select x1.sta_id,time,vis100
from x1,x2,$db.locations
where x1.sta_id = x2.sta_id
and x1.loc_id = x2.loc_id
and x1.loc_id = $db.locations.id
and cast(abs(x1.time - $valid_secs) as signed) = min_dif
group by sta_id
EOI
    ;
if($DEBUG) {print "$query;\n";}
my $sth = $dbh->prepare($query);
$sth->execute();
my($id,$time,$vis100);
$sth->bind_columns(\$id,\$time,\$vis100);
my $count=0;
my $vis_count=0;
my $vis_out;
while($sth->fetch()) {
    if($vis100) {
	$vis_count++;
	$vis_out = $vis100;
    } else {
	# no vis report in HF-METAR
	$vis_out = undef;
    }
    # remove any obs from this id within this hour that don't have as well-matched a time
    # possibly from previous loading with incomplete data
    my $rows_deleted = $sth_clean_vis->execute($id,$time,$valid_secs - 450,$valid_secs + 450);
    if($rows_deleted > 0) {
	print "removing less-well-matched time for $id ($rows_deleted times)\n";
    }
    $sth_load_vis->execute($id,$time,$vis100);
    if($count++ < 40) {
	my $time_str = gmtime($time);
	print "$id,$time_str,$vis_out\n";
    }
}
print "$count metars world-wide stored for valid hour $time_str run at $current_time_str \n\n";
$sth->finish();
$dbh->disconnect();
}

# clean up tmp directory
require "./clean_tmp_dir.pl";
clean_tmp_dir();

