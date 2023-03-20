#!/usr/bin/perl
#
use strict;
use English;
use DBI;
    
my $DEBUG=1;
# connect to the database
$ENV{DBI_DSN} = "DBI:mysql:madis3:wolphin.fsl.noaa.gov";
$ENV{DBI_USER} = "sfc_driver5";
$ENV{DBI_PASS} = "driver5";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 0, PrintError => 1});

my $start_time =    1407628800;

for (my$hr_time = $start_time;$hr_time <  1407787200;$hr_time += 3600) {
    my $table = "hr_obs_$hr_time";
    my $query1 =<<"EOI"
select floor(time%3600/1800) as half_hr,count(*) as N
,from_unixtime(min(time)) as min
,from_unixtime(max(time)) as max
from $table
group by half_hr
order by half_hr desc
EOI
;
    my $query2=<<"EOI"
select floor(time%3600/1800) as half_hr,count(*) as N
,from_unixtime(min(time)) as min
,from_unixtime(max(time)) as max
from obs
where 1=1
and time >= $hr_time-1800 and time < $hr_time+1800
group by half_hr
order by half_hr desc
EOI
;

    my $time_str;
    my $sth;
    $time_str = gmtime($hr_time);
    my ($half_hr,$n,$min,$max);
    #print $query;
    if(0) {
    $time_str = gmtime($hr_time);
    $sth = $dbh->prepare($query1);
    $sth->execute();
     $sth->bind_columns(\$half_hr,\$n,\$min,\$max);
    print "checking  in $table $time_str\n";
    while($sth->fetch()) {
	print "\t$n in range $min, $max\n";
    }
    $sth->finish();
    }
    $sth = $dbh->prepare($query2);
    $sth->execute();
    $sth->bind_columns(\$half_hr,\$n,\$min,\$max);
    print "checking  in obs $time_str\n";
    while($sth->fetch()) {
	print "\t$n in range $min, $max\n";
    }
    $sth->finish();
   
    
 }
