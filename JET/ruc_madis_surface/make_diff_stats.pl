#!/usr/bin/perl -T
use strict;

# PREAMBLE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

my $DEBUG=1;  # MAKE THIS NON-ZERO TO PRODUCE EXTRA DEBUG PRINTOUT

#for security, must set the PATH explicitly
$ENV{'PATH'}="";
use lib "./";

#get directory and URL
use File::Basename;
my ($basename,$thisDir) = fileparse($0);
$basename =~ m|([\-\~\.\w]*)|;  # untaint
$basename = $1;
$thisDir =~ m|([\-\~\.\w\/]*)|; # untaint
$thisDir = $1;

# END OF PREAMBLE ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

use DBI;
use Time::Local;

#connect
require "$thisDir/set_connection3.pl";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $query = "";
my $sth;

# get limits from the database
$query = qq|
    select S_for_DIR_limit
    from limits|;
my $sth_lim = $dbh->prepare($query);
$sth_lim->execute();
my($S_for_DIR_limit) = $sth_lim->fetchrow_array();
$sth_lim->finish();

my ($startSecs,$endSecs,$n_days);
$n_days = 10;
$endSecs = time();
$endSecs -= $endSecs%(24*3600); # put on a day boundary
$startSecs = $endSecs - $n_days*24*3600;

my $table_name = "${n_days}_day_18_22Z";
$query =<<"EOQ";
DROP TABLE IF EXISTS $table_name
EOQ
    ;
$dbh->do($query);
$query=<<"EOQ";
create table $table_name
#explain
select stations.id,stations.name,net,
 min(o.time) as min_time,
 max(o.time) as max_time,
 count(o.temp) as N_T,
 round(avg(o.temp)/10,2) as avg_T,
 round(avg(o.temp-m.temp)/10,2) as bias_T,
 round(avg(o.temp-m2.temp)/10,2) as bias_T2,
 round(std(o.temp-m.temp)/10,2) as std_T,
 round(std(o.temp-m2.temp)/10,2) as std_T2,
 count(o.ws) as N_S,
 round(avg(o.ws),2) as avg_S,
 round(avg(cast(o.ws-m.ws as signed)),2) as bias_S,
 round(avg(cast(o.ws-m2.ws as signed)),2) as bias_S2,
 round(std(cast(o.ws-m.ws as signed)),2) as std_S,
 round(std(cast(o.ws-m2.ws as signed)),2) as std_S2,
 sum(if(o.ws  > $S_for_DIR_limit &&
	m.ws > $S_for_DIR_limit,1,0)) as N_DIR,
 sum(if(o.ws  > $S_for_DIR_limit &&
	m2.ws > $S_for_DIR_limit,1,0)) as N_DIR2,
 round(avg(if(o.ws  > $S_for_DIR_limit &&
	m.ws > $S_for_DIR_limit,
	if(cast(o.wd-m.wd as signed) between -180 and 180,
	   cast(o.wd-m.wd as signed),
	   if(cast(o.wd-m.wd as signed) > 180,
	      cast(o.wd-m.wd as signed)-360,
	      cast(o.wd-m.wd as signed)+360)),null)),2) as bias_DIR,
 round(avg(if(o.ws  > $S_for_DIR_limit &&
	m2.ws > $S_for_DIR_limit,
	if(cast(o.wd-m2.wd as signed) between -180 and 180,
	   cast(o.wd-m2.wd as signed),
	   if(cast(o.wd-m2.wd as signed) > 180,
	      cast(o.wd-m2.wd as signed)-360,
	      cast(o.wd-m2.wd as signed)+360)),null)),2) as bias_DIR2,
 round(std(if(o.ws  > $S_for_DIR_limit &&
	m.ws > $S_for_DIR_limit,
	if(cast(o.wd-m.wd as signed) between -180 and 180,
	   cast(o.wd-m.wd as signed),
	   if(cast(o.wd-m.wd as signed) > 180,
	      cast(o.wd-m.wd as signed)-360,
	      cast(o.wd-m.wd as signed)+360)),null)),2) as std_DIR,
 round(std(if(o.ws  > $S_for_DIR_limit &&
	m2.ws > $S_for_DIR_limit,
	if(cast(o.wd-m2.wd as signed) between -180 and 180,
	   cast(o.wd-m2.wd as signed),
	   if(cast(o.wd-m2.wd as signed) > 180,
	      cast(o.wd-m2.wd as signed)-360,
	      cast(o.wd-m2.wd as signed)+360)),null)),2) as std_DIR2,
 round(sqrt(sum(pow(o.ws,2)+pow(m.ws,2)-2*o.ws*m.ws*cos((o.wd-m.wd)/5729.58))/count(o.wd)),2)
    as rms_W,
 round(sqrt(sum(pow(o.ws,2)+pow(m2.ws,2)-2*o.ws*m2.ws*cos((o.wd-m2.wd)/5729.58))/count(o.wd)),2)
    as rms_W2,
 round(sqrt(sum(pow(o.ws,2)+pow(m.ws,2)-2*o.ws*m.ws*cos((o.wd-m.wd)/5729.58))/count(o.wd) -
	    pow(avg(o.ws*cos(o.wd/5729.58) - m.ws*cos(m.wd/5729.58)),2)-
	    pow(avg(o.ws*sin(o.wd/5729.58) - m.ws*sin(m.wd/5729.58)),2)
	    ),2)
    as var_W,
 round(sqrt(sum(pow(o.ws,2)+pow(m2.ws,2)-2*o.ws*m2.ws*cos((o.wd-m2.wd)/5729.58))/count(o.wd) -
	    pow(avg(o.ws*cos(o.wd/5729.58) - m2.ws*cos(m2.wd/5729.58)),2)-
	    pow(avg(o.ws*sin(o.wd/5729.58) - m2.ws*sin(m2.wd/5729.58)),2)
	    ),2)
    as var_W2,
 count(o.dp) as N_Td,
 round(avg(o.dp)/10,2) as avg_Td, 
 round(avg(o.dp-m.dp)/10,2) as bias_Td,
 round(avg(o.dp-m2.dp)/10,2) as bias_Td2,
 round(std(o.dp-m.dp)/10,2) as std_Td,
 round(std(o.dp-m2.dp)/10,2) as std_Td2
 from dev as m, dev2 as m2, obs as o,stations, locations
 where m.sta_id = o.sta_id
 and m.sta_id = stations.id
 and m2.sta_id = o.sta_id
 and o.loc_id = locations.id
 #and lat between 44*182 and 46*182
 #and lon between -95*182 and -91*182
 and m.fcst_len = 1
 and m.fcst_len = m2.fcst_len
 and m.time = o.time
 and m2.time = o.time
 and o.time >= $startSecs
 and o.time < $endSecs
 and hour(from_unixtime(o.time)) >= 18
 and hour(from_unixtime(o.time)) <= 21
 group by stations.id
EOQ
    ;
if($DEBUG) {
    print "query is $query\n";
}

$dbh->do($query);
$dbh->disconnect();

sub sql_date {
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return sprintf("%4d-%2.2d-%2.2d %2.2d:%2.2d:%2.2d",
		   $year,$mon,$mday,$hour,$min,$sec);
}
  
