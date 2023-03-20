#!/usr/bin/perl
#SBATCH -J vis_obs
#SBATCH --mail-user=verif-amb.gsl@noaa.gov                                                                                          
#SBATCH --mail-type=FAIL
#SBATCH -A amb-verif
#SBATCH -n 1
#SBATCH -p service 
#SBATCH -t 02:00:00
#SBATCH --mem=1G
#SBATCH -D .
#SBATCH -e /home/amb-verif/visibility/tmp/vis_obs.e%j
#SBATCH -o /home/amb-verif/visibility/tmp/vis_obs.o%j
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
use CGI;
use DBI;

#connect
my $db_machine = $ARGV[1] || "wolphin.fsl.noaa.gov";
my $db = "madis3";
if($db_machine =~ /hopper3/) {
    $db = "madis5";
}
require "./set_connection.pl";
$ENV{DBI_DSN} = "DBI:mysql:visibility:$db_machine";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $query = "";
my $sth;

my $current_secs = time();
# valid secs is start of current hour
# or n_hours back (in ARGV[0])
my $valid_secs = $current_secs - $current_secs%3600 - abs($ARGV[0])*3600;

$query =<<"EOI"
replace into obs values(?,?,?)
EOI
    ;
my $sth_load_vis = $dbh->prepare($query);

$query =<<"EOI"
create temporary table x1
(UNIQUE id_time (sta_id,time))
engine = memory
select sta_id,time,loc_id,vis100
from $db.obs,$db.stations where
1=1
and sta_id = $db.stations.id
and $db.stations.net = "METAR"
and obs.time >= $valid_secs - 1800
and obs.time < $valid_secs + 1800
EOI
    ;
if($DEBUG) {print "$query;\n";}
$dbh->do($query);

$query =<<"EOI"
create temporary table x2
(index (sta_id,loc_id,min_dif))
engine = memory
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
# include whole RR region
# degrees are scaled by 182 in the $db database
and lat > 1*182 and lat < 82*182
and (lon < -3*182 or lon > 169*182)
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
    $count++;
    if($vis100) {
	$vis_count++;
	$vis_out = $vis100;
    } else {
	# no vis report in METAR
	$vis_out = undef;
    }
   $sth_load_vis->execute($id,$time,$vis_out);
    if($count++ < 30) {
	print "$id,$time,$vis_out\n";
    }
}
print "$count metars, $vis_count with visibility info, stored\n";
$sth->finish();
$dbh->disconnect();

# clean up tmp directory
my $purge_time_days = $ENV{vis_purge_time_days}+0; # convert to a number
print("purging files in tmp directory older than $purge_time_days days\n");
if($purge_time_days == 0) {
    die "bad purge_time_days: |$purge_time_days|\n";
}
opendir(DIR,"tmp") ||
    die "cannot open tmp/: $!\n";
my @allfiles = grep !/^\.\.?$/,readdir DIR;
foreach my $file (@allfiles) {
    $file = "tmp/$file";
    #print "file is $file\n";
    # untaint
    $file =~ /(.*)/;
    $file = $1;
    if(-M $file > $purge_time_days) {
	print "unlinking $file\n";
	unlink "$file" || print "Can't unlink $file $!\n";
    }
}
closedir DIR;


