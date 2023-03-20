#!/usr/bin/perl
use strict;
use DBI;

# connect to the database
$ENV{DBI_DSN} = "DBI:mysql:madis3:wolphin.fsl.noaa.gov";
$ENV{DBI_USER} = "sfc_driver5";
$ENV{DBI_PASS} = "driver5";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $valid_secs =  1318338000;
require "./get_obs_at_hr_q.pl";

get_obs_at_hr_q($valid_secs,$dbh);

