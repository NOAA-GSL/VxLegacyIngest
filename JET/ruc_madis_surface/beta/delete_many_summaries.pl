#!/usr/bin/perl
#
use strict;
use DBI;
use Time::Local;
my $DEBUG=1;
require "./set_connection.pl";
$ENV{DBI_DSN} = "DBI:mysql:surface_sums:wolphin.fsl.noaa.gov";
# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $db_name = "madis3";
my $query;
my $model = "Op13";
my @fcst_lens = (1,0,3,6,9,12);
my @regions = qw[ALL_RUC E_RUC W_RUC ALL_HRRR E_HRRR W_HRRR];

my $input_time = $ARGV[0];
for(my $valid_time =  $input_time ;
    $valid_time <    $input_time + 1;
    $valid_time += 3600) {
    my $time_str = gmtime($valid_time);
    print "deleting summaries for $time_str\n";
    foreach my $fcst_len (@fcst_lens) {
	foreach my $region (@regions) {
	    my $table = sprintf("surface_sums.%s_%d_metar_%s",
				$model,$fcst_len,$region);
	    my $hour = ($valid_time % (24*3600))/3600;
	    my $valid_day = $valid_time - 3600*$hour;
	    my $query = "delete from $table where valid_day = $valid_day and hour = $hour";
	    print "$query\n";
	    $dbh->do($query);
	}
    }
}

