#!//usr/bin/perl

my $valid_time = 1273233600 + 13*3600;
    my $valid_day = sql_date($valid_time);
    my $valid_hours_1970 = int($valid_time/3600);
    my $valid_hour = $valid_hours_1970 % 24;
    my $query=<<"EOI";
	select count(*) from $sums_table0
	where 1=1
	and date = '$valid_day'
	and hour = $valid_hour
	and fcst_len = $fcst_len
EOI
	;
    print "$query\n";


sub sql_date {
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return sprintf("%4d-%2.2d-%2.2d",
		   $year,$mon,$mday);
}
