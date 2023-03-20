#!/usr/bin/perl
#
use strict;
use DBI;
use Time::Local;
my $DEBUG=1;
require "./set_connection.pl";
$ENV{DBI_DSN} = "DBI:mysql:madis3:wolphin.fsl.noaa.gov";
# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $db_name = "madis3";
my $query;

$query = qq{show tables like "%RRret%"};
my $sth = $dbh->prepare($query);
$sth->execute();
while(my @ary = $sth->fetchrow_array()) {
    my $table = $ary[0];
    #print "$table\n";
    if($table =~ /RRret_hyb_May2013_wrf351_DA/) {
	print "NOT DROPPING $table\n";
    } else {
	my $cmd = "drop table $table";
	print "$cmd\n";
	$dbh->do($cmd);
    }
}
