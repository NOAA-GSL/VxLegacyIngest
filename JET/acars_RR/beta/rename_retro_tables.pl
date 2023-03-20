#!/usr/bin/perl
#
use strict;


use DBI;
$ENV{DBI_DSN} = "DBI:mysql:acars_RR:wolphin.fsl.noaa.gov";
$ENV{DBI_USER} = "sfc_retro";
$ENV{DBI_PASS} = "EricHaidao";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $query;
my $sth;

# see if the needed tables exist
$query =qq|show tables like "RAPv5_jul2018_DAretro0%"|;
print "$query\n";
$sth = $dbh->prepare($query);
$sth->execute();
my($table);
$sth->bind_columns(\$table);
while($sth->fetch()) {
    my $new_table = $table;
    $new_table =~ s/DAretro0/DAretro0_A/;
    print "$table -> $new_table\n";
    $query = "rename table $table to $new_table";
    $dbh->do($query);
    
}


