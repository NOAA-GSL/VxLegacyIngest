#!/usr/bin/perl
#
require "./update_summaries_q_coastal.pl";

my $start_secs = 1378857600;
my $end_secs = 1378908000;
my $data_source = "RR1h";
my $fcst_len = 0;
my $region = "ALL_HRRR_coastal";

# connect to the database
$ENV{DBI_DSN} = "DBI:mysql:madis3:wolphin.fsl.noaa.gov";
$ENV{DBI_USER} = "sfc_driver5";
$ENV{DBI_PASS} = "driver5";
my $dbh;
$dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});

for(my $valid_time = $start_secs;$valid_time< $end_secs;$valid_time+=3600) {
    update_summaries_q_coastal($data_source,$valid_time,$fcst_len,$region,$dbh,$db_name,1);
}

