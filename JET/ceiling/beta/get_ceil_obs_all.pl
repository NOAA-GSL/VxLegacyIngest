#!/usr/bin/perl
#PBS -d .
#PBS -N ceil_get_obs
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

#connect
my $db_machine = $ARGV[1] || "emb-proddb.gsd.esrl.noaa.gov";
my $db = "madis3";
$ENV{DBI_DSN} = "DBI:mysql:ceiling_all:$db_machine";
$ENV{DBI_USER} = "wcron0_user";
$ENV{DBI_PASS} = "cohen_lee";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $query = "";
my $sth;

my $current_secs = time();
# valid secs is start of current hour
# or n_hours back (in ARGV[0])
# or ARGV[0]  could be a calendar time
my $valid_secs;
if($ARGV[0] > 315532800) { # 1-Jan-1980
    $valid_secs = $ARGV[0];
} else {
    $valid_secs = $current_secs - $current_secs%3600 - abs($ARGV[0])*3600;
}

my $time_str = gmtime($valid_secs);
my $current_time_str = gmtime(time());
print "$valid_secs ($time_str), hrs_ago: $ARGV[0]. run at $current_time_str\n";

$query =<<"EOI"
replace into obs values(?,?,?)
EOI
    ;
my $sth_load_ceil = $dbh->prepare($query);

$query=<<"EOI"
delete from obs
where madis_id = ?
and time != ?
and time >= ?
and time < ?
EOI
    ;
my $sth_clean_ceil = $dbh->prepare($query);

$query =<<"EOI"
create temporary table x1
(UNIQUE id_time (sta_id,time))
ENGINE = MEMORY
select sta_id,time,loc_id,cvr,sky_id
from $db.obs,$db.sky where
    sky_id = $db.sky.id    
and obs.time >= $valid_secs - 1800
and obs.time < $valid_secs + 1800
EOI
    ;
if($DEBUG) {print "$query;\n";}
$dbh->do($query);

$query =<<"EOI"
select x1.sta_id,time,cvr,sky_id
from x1,$db.locations
where 1=1
and x1.loc_id = $db.locations.id
group by sta_id
EOI
    ;
if($DEBUG) {print "$query;\n";}
my $sth = $dbh->prepare($query);
$sth->execute();
my($id,$time,$cvr,$sky_id);
$sth->bind_columns(\$id,\$time,\$cvr,\$sky_id);
my $count=0;
my $ceil_dft = 6000;		# code clear as 60,000 ft
while($sth->fetch()) {
    $ceil_dft = 6000;		# code clear as 60,000 ft
    if($cvr =~ m|BKN/(\d+)| ||
       $cvr =~ m|OVC/(\d+)| ||
       $cvr =~ m|VV/(\d+)|) {
	$ceil_dft = $1 * 10;   # put in tens of ft
    }
    # remove any obs from this id within this hour that don't have as well-matched a time
    # possibly from previous loading with incomplete data
    my $rows_deleted = $sth_clean_ceil->execute($id,$time,$valid_secs - 1800,$valid_secs + 1800);
    if($rows_deleted > 0) {
	print "removing less-well-matched time for $id ($rows_deleted times)\n";
    }
    $sth_load_ceil->execute($id,$time,$ceil_dft);
    if($count++ < 40) {
	print "CLOUD COVER $id,$time, sky_id: $sky_id, |$cvr| $ceil_dft\n";
    }
}
print "$count metars world-wide stored for valid hour $time_str run at $current_time_str \n\n";
$sth->finish();
$dbh->disconnect();

# clean up tmp directory
require "./clean_tmp_dir.pl";
clean_tmp_dir();

