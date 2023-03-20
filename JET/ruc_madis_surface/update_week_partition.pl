#!/usr/bin/perl -T
use strict;

# PREAMBLE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

my $DEBUG=1;  # MAKE THIS NON-ZERO TO PRODUCE EXTRA DEBUG PRINTOUT

#for security, must set the PATH explicitly
$ENV{'PATH'}="";
use lib "./";

#get directory and URL
use File::Basename;
my ($basename,$thisDir) = fileparse($0);
$basename =~ m|([\-\~\.\w]*)|;  # untaint
$basename = $1;
$thisDir =~ m|([\-\~\.\w\/]*)|; # untaint
$thisDir = $1;

# END OF PREAMBLE ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

use DBI;
use Time::Local;

#connect
require "$thisDir/set_connection3.pl";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 0, PrintError => 1});
my $query = "";
my $rows;

my $table = $ARGV[0];
unless($table) {
    print "usage: update_week_partition.pl <table_name> <days to keep>\n";
}
# get time to delete before
my $n_days = $ARGV[1] || 90;
my $deleteSecs = time() - $n_days*24*3600;
# find week number (after 1/1/1970)
my $week_to_delete = int($deleteSecs/(7*24*3600));

# delete partition(s)
$query = "show create table $table";
my @result = $dbh->selectrow_array($query);
my @lines = split(/\n/,$result[1]);
foreach my $line (@lines) {
    if($line =~ /PARTITION week(....)/) {
	my $partition_week = $1;
	if($partition_week <= $week_to_delete) {
	    $query = "alter table $table drop partition week$partition_week";
	    print "$query\n";
	    $dbh->do($query);
	} else {
	    #print "NOT dropping partition week$partition_week\n";
	}
    }
}

# now add a new partition
my $currentSecs = time();
# get start of current week
my $currentWeekSecs = $currentSecs - $currentSecs % (7*24*3600);
# get start of 3 weeks hence
my $addSecs = $currentWeekSecs + 3*7*24*3600;
my $week_to_add = int($addSecs/(7*24*3600)) - 1;
$query = "alter table $table add partition (partition week$week_to_add values less than ($addSecs))";
print "$query\n";
$dbh->do($query);

$dbh->disconnect();

