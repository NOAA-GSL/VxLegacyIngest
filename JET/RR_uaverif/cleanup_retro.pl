#!/usr/bin/perl

# use this after a retro run has been loaded into a database.
# this script will keep the summary files for the retro run that are in
# the ruc_ua_sums2 database, and that generate statistics on the web for
# various regions.
# if, however, you still need to see individual soundings from the retro run,
# or want to display soundings for individual sites at rucsoundings.noaa.gov,
# or want to display summary statistics *for specific RAOB sites* (rather than for regions)
# do NOT run this script, because you'll need the soundings_table.

use strict;
my $DEBUG=1;
use DBI;
my $experiment_name = $ARGV[0];
unless($experiment_name) {
    die "Usage: cleanup_retro.pl <experiment_name>\n";
}
my $soundings_table = "soundings.${experiment_name}_raob_soundings";
my $model_table = "ruc_ua.${experiment_name}";

#change to the proper directory
use File::Basename; 
my ($basename,$thisDir) = fileparse($0);

use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";
$thisDir = $ENV{PWD};

#set database connection parameters
require "./set_connection.pl";
$ENV{DBI_DSN} = "DBI:mysql:soundings:wolphin.fsl.noaa.gov";

# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {PrintError => 1});
my $sth;
my $query="";

$query = qq{drop table $soundings_table};
print "$query\n";
$dbh->do($query);

$query = qq{drop table $model_table};
print "$query\n";
$dbh->do($query);
