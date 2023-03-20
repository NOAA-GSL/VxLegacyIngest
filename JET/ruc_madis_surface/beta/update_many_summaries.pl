#!/usr/bin/perl
#
use strict;
use Time::Local;
require "./update_summaries_v3u_new.pl";
require "./get_obs_at_hr_q.pl";
my $DEBUG=1;
require "./set_connection.pl";
$ENV{DBI_DSN} = "DBI:mysql:surface_sums2:wolphin.fsl.noaa.gov";
# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $db_name = "madis3";
my $query;
my $model = "HRRR_OPS";
my @fcst_lens = (0,1,2,3,6,9,12,15,18,21,24,27,30,33,36);
my @regions = qw[ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI];

for(my $valid_time = 1528120800  ;
    $valid_time >    1527552000;
    $valid_time -= 3600) {
    my $time_str = gmtime($valid_time);
    print "\n\nupdating summaries for $time_str\n";
    get_obs_at_hr_q($valid_time,$dbh);
    foreach my $fcst_len (@fcst_lens) {
	foreach my $region (@regions) {
	    update_summaries_v3u_new($model,$valid_time,$fcst_len,$region,$dbh,$db_name,$DEBUG);
	}
    }
}

