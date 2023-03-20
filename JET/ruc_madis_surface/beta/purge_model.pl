#!/usr/bin/perl
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

my $model = $ARGV[0];

#connect
require "$ENV{HOME}/set_connection51.pl";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 0, PrintError => 1});
my $query = "";
my $rows;

# get time to delete before
my $n_days = 180;
my $deleteSecs = time() - $n_days*24*3600;
# fine week number (after 1/1/1970)
my $week_to_delete = int($deleteSecs/(7*24*3600));

my $partition_name = "week$week_to_delete";
$query = "alter table $model drop partition $partition_name";
print "$query\n";
$dbh->do($query);

# now add a new partition 2 week's hence
my $currentSecs = time();
# get start of current week
my $currentWeekSecs = $currentSecs - $currentSecs % (7*24*3600);
# get start of 3 weeks hence
my $addSecs = $currentWeekSecs + 3*7*24*3600;
my $week_to_add = int($addSecs/(7*24*3600)) - 1;
$query = "alter table $model add partition (partition week$week_to_add values less than ($addSecs))";
print "$query\n";
$dbh->do($query);

$dbh->disconnect();

