#!/usr/bin/perl
#
use strict;

my $data_source = $ARGV[0];
if(!defined $data_source) {
    print "usage: ./make_retro_tables.pl <experiment (or model) name.\n";
    exit();
}

my $fl_file = "${data_source}_fcst_lens";
open(F,"$fl_file") ||
    die "could not open $fl_file: $!";
my $fl = <F>;
chomp $fl;
my @fcst_lens = split(/\,/,$fl);
print "forecast lengths to verify: @fcst_lens\n";
close F;

use DBI;
$ENV{DBI_DSN} = "DBI:mysql:acars_RR:wolphin.fsl.noaa.gov";
$ENV{DBI_USER} = "sfc_retro";
$ENV{DBI_PASS} = "EricHaidao";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $query;

my @regions = qw(Full HRRR);
if($data_source =~ /^HRRR/) {
    @regions = qw(Full);
}
# see if the needed tables exist
$query =qq|show tables like "${data_source}_${fcst_lens[0]}_${regions[0]}"|;
print "$query\n";
my $result = $dbh->selectrow_array($query);
unless($result) {
    foreach my $fcst_len (@fcst_lens) {
	my $table = "${data_source}_${fcst_len}";
	$query = qq[create table $table like template_obs];
	print "$query\n";
	$dbh->do($query);
	foreach my $region (@regions) {
	    $table = "${data_source}_${fcst_len}_${region}_sums";
	    $query = qq[create table $table like template_sums];
	    print "$query\n";
	    $dbh->do($query);
	}
    }
} else {
    print "tables already exist for $data_source. Delete them if you need to start over.\n";
}


