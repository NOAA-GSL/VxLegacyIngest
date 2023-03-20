#!/usr/bin/perl

require "./update_bad_tails.pl";
use DBI;
#set database connection parameters
$ENV{DBI_DSN} = "DBI:mysql:acars_RR:wolphin.fsl.noaa.gov;mysql_local_infile=1";
$ENV{DBI_USER} = "wcron0_user";
$ENV{DBI_PASS} = "cohen_lee";
# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1, PrintWarn => 1});
update_bad_tails($dbh,0,0);
