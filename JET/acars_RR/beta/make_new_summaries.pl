#!/usr/bin/perl
use strict;
use strict;
use Time::Local;
use DBI;
$ENV{DBI_DSN} = "DBI:mysql:acars_RR:wolphin.fsl.noaa.gov";
$ENV{DBI_USER} = "wcron0_user";
$ENV{DBI_PASS} = "cohen_lee";
# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 0, PrintError => 1});
my $query= qq{show tables like "RAP_iso%sums"};
my $old_table;
my $sth = $dbh->prepare($query);
$sth->execute();
while(($old_table) = $sth->fetchrow_array) {
    unless($old_table =~ /130/) {
	my $new_table = $old_table;
	$new_table = "clean$old_table";
	$query = qq{create table $new_table like $old_table};
	print "$query\n";
	$dbh->do($query);
    }
    
}
