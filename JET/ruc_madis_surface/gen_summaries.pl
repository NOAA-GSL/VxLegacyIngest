#!/usr/bin/perl
#
use strict;
use Time::Local;
use DBI;
require "./set_connection3.pl";
$ENV{DBI_DSN} = "DBI:mysql:surface_sums:wolphin.fsl.noaa.gov";
# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
foreach my $data_source (qw(NAM)) {
    my @fcst_lens = (1,0,3,6,9,12);
   foreach my $fcst_len (@fcst_lens) {
	foreach my $region (qw[HWT STMAS_CI]) {
	    my $table = "${data_source}_${fcst_len}_metar_q_${region}";
	    my $query;
	    $query = qq[create table $table like template_q];
	    print "$query\n";
	    $dbh->do($query);
	}
    }
}
