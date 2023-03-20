#!/usr/bin/perl
use strict;

# PREAMBLE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

my $DEBUG=1;  # MAKE THIS NON-ZERO TO PRODUCE EXTRA DEBUG PRINTOUT

#for security, must set the PATH explicitly
$ENV{'PATH'}="";
   
#get directory
use File::Basename;
my ($basename,$thisDir) = fileparse($0);
$basename =~ m|([\-\~\.\w]*)|;  # untaint
$basename = $1;
$thisDir =~ m|([\-\~\.\w\/]*)|; # untaint
$thisDir = $1;

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
    print "basename is $basename\n";
    print "\n";
}
# end useful DEBUGGING info ^^^^^^^^^^^^^^^^^
# END PREAMBLE^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

my $expname = $ARGV[0];
print "experiment name is $expname\n";

use lib "/misc/ihome/moninger/DBD-mysql-2.9004/lib";
use lib "/misc/ihome/moninger/DBD-mysql-2.9004/blib/arch/auto/DBD/mysql";
use DBI;
# set connection parameters for this directory
$ENV{DBI_DSN} = "DBI:mysql:ruc_ua_sums2:wolphin.fsl.noaa.gov";
$ENV{DBI_USER} = "reader";
$ENV{DBI_PASS} = "reader_lehar";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $query = "select unix_timestamp(max(date)) + 3600*max(hour) from ${expname}_reg0";
# remove leading whitespace from query so it is easy to reuse
$query =~ s/^\s+//gm;
if($DEBUG) {
    print "$query;\n";
}
my $sth = $dbh->prepare($query);
$sth->execute();
my $lastSecs=0;
$sth->bind_columns(\$lastSecs);
$sth->fetch();
print "lastSecs is $lastSecs\n";
# force a complete redo
$lastSecs = 0;
my $startSecs = $lastSecs || 1164542400; # Sun 26 Nov 106 12:00:00 (day 330)
$sth->finish();
$dbh->disconnect();

my $endSecs = 1165363201; # Wed 6 Dec 106 00:00:00 (day 340) + 1 sec
my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday);

for(my $time=$startSecs;$time<$endSecs;$time+=12*3600) {
    #foreach my $fcst_len (0,1,3,6,9,12) {
    foreach my $fcst_len (0) {
	my $run_time = $time - 3600*$fcst_len;
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) =
	    gmtime($run_time);
	$yday++;			# make it 1-based
	my $atime = sprintf("%02d%03d%02d",$year%100,$yday,$hour);
	my $command = "./agen_raob_sites2.pl $expname $fcst_len $atime";
	print "COMMAND IS $command\n";
	system($command) &&
	    die "cannot execute $command: $!";
    }
}
