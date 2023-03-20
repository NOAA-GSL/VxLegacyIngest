#!/usr/bin/perl
#
use strict;

my $data_source = $ARGV[0];
if(!defined $data_source) {
    print "usage: ./make_retro_tables2.pl <experiment (or model) name.\n";
    exit();
}

use DBI;
$ENV{DBI_DSN} = "DBI:mysql:acars_RR2:wolphin.fsl.noaa.gov";
$ENV{DBI_USER} = "sfc_retro";
$ENV{DBI_PASS} = "EricHaidao";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $query;

my @regions = qw(Full HRRR);
if($data_source =~ /^HRRR/) {
    @regions = qw(Full);
}
# see if the needed tables exist
$query =qq|show tables like "${data_source}_${regions[0]}"|;
print "$query\n";
my $result = $dbh->selectrow_array($query);
unless($result) {
	my $table = "${data_source}";
	$query = qq[create table $table like template_retro];
	print "$query\n";
	$dbh->do($query);
	foreach my $region (@regions) {
	    $table = "${data_source}_${region}_sums";
	    $query = qq[create table $table like template_sums];
	    print "$query\n";
	    $dbh->do($query);
        }
} else {
    print "tables already exist for $data_source. Delete them if you need to start over.\n";
}


