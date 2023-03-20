#!/usr/bin/perl
#
#  Set the name of the job.
#$ -N ruc_madis
#  Make sure that the .e and .o file arrive in the working directory
#$ -cwd
#
#  Set the account
#$ -A wrfruc
#
#  Ask for 1 cpus of type service
#$ -pe service 1
#
#  My code is re-runnable
#$ -r y
#
# send mail on abort, end
#$ -m a
#$ -M verif-amb.gsl@noaa.gov
#
#  The max walltime 
#$ -l h_rt=01:00:00
#
#$ -e tmp/
#$ -o tmp/
#
use strict;
my $thisDir = $ENV{SGE_O_WORKDIR};
unless($thisDir) {
    # we've been called locally instead of qsubbed
    use File::Basename; 
    my ($basename,$thisDir2) = fileparse($0);
    $thisDir = $thisDir2;
}

my $DEBUG=1;

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
# END PREAMBLE^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#connect
use DBI;
require "$thisDir/set_connection3.pl";
require "$thisDir/update_summaries2.pl";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $query = "";
my $sth;

my $hrs_ago = abs($ARGV[0]) || 0;
my $db_machine = $ARGV[1] || "wolphin";
my $db_name = $ARGV[2] || "madis3";
print "hrs_ago is $hrs_ago\n";

my $time = time() - 5*3600 - $hrs_ago*3600;
# get on hour boundary
$time -= $time%3600;

foreach my $fcst_len (1,6) {
    my $run_time = $time - 3600*$fcst_len;
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) =
	gmtime($run_time);
    $yday++;			# make it 1-based
    my $atime = sprintf("%02d%03d%02d",$year%100,$yday,$hour);
    my $command;
    $command = "./agen_madis_sites.pl Bak13 $fcst_len $atime $db_machine $db_name";
    print "COMMAND IS $command\n";
    system($command) &&
	die "cannot execute $command: $!";
    foreach my $region (qw[RUC E_RUC W_RUC]) {
	update_summaries2("Bak13",$time,$fcst_len,$region,$dbh,$DEBUG);
    }
}

# now use the new Bak13 sta_id's and times to update
# the obs_at_hr table, which is used to make
# 7-day obs-Bak13 statistics.

$query=<<"EOQ";
replace into obs_at_hr
(sta_id,time,temp,dp,slp,wd,ws,precip,vis100)
# describe
select o.sta_id,o.time,o.temp,o.dp,o.slp,o.wd,o.ws,o.precip,o.vis100
from Bak13a as m,obs as o
where 1=1
and m.time >= $time - 1800
and m.time < $time + 1800
and m.time = o.time
and m.sta_id = o.sta_id
EOQ
    ;
print "$query";
my $n_rows = $dbh->do($query);
print "$n_rows rows... \n";

#finish up
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
