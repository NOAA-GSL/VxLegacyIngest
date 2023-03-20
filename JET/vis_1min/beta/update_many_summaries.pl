#!/usr/bin/perl
use strict;
require "./update_summaries.pl";

my $model = "HRRR";
my @fcst_len_mins = ();
for(my $min=0;$min<=6*60;$min+=15) {
    push(@fcst_len_mins,$min);
}
for(my $valid_time = 1538812800;$valid_time <=1539018000;$valid_time += 15*60) {
    foreach my $fcst_len_min (@fcst_len_mins) {
	my $fcst_len_hr = int($fcst_len_min/60);
	my $minute = $fcst_len_min - 60*$fcst_len_hr;
	my $time_str = gmtime($valid_time);
	print "$time_str $fcst_len_hr, $minute\n";
update_summaries($model,$valid_time,$fcst_len_hr,$minute,1);
    }}
