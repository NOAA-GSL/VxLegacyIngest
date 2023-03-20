#!/usr/bin/perl
use strict;
require "./load_summaries.pl";

use DBI;
#set database connection parameters
$ENV{DBI_DSN} = "DBI:mysql:acars_RR:wolphin.fsl.noaa.gov;mysql_local_infile=1";
$ENV{DBI_USER} = "wcron0_user";
$ENV{DBI_PASS} = "cohen_lee";
# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1, PrintWarn => 1});

my $model = "RAP_dev3";
my $fcst_len = 1;
my $min_date = '2013-05-10 06:30:00';
my $max_date = '2013-05-28 18:30:00';

load_summaries($dbh,$model,$fcst_len,$min_date,$max_date,-1);
load_summaries($dbh,$model,$fcst_len,$min_date,$max_date,0);
load_summaries($dbh,$model,$fcst_len,$min_date,$max_date,1);
load_summaries($dbh,$model,$fcst_len,$min_date,$max_date,2);

sub print_warn {
    my $dbh = shift;
    my $warnings = $dbh->selectall_arrayref('SHOW WARNINGS');
    for my $row (@$warnings) {
	print "@{$row}\n";
    }
}
