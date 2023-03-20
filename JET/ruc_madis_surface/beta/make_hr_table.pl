#!/usr/bin/perl
#
use strict;
use English;
use DBI;
require "get_obs_at_hr_q.pl";
    
my $DEBUG=1;
# connect to the database
$ENV{DBI_DSN} = "DBI:mysql:madis3:wolphin.fsl.noaa.gov";
$ENV{DBI_USER} = "sfc_driver5";
$ENV{DBI_PASS} = "driver5";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});

my $valid_time =  1406322000-3*3600;
get_obs_at_hr_q($valid_time,$dbh);

