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

my $table_name = "18_21Z_net_dev2_Aug07";
my ($startSecs,$endSecs);
$endSecs = time()-7200;
$endSecs -= $endSecs % 86400; # start of today
$endSecs = 1188604800;		# 1 Sep 2007
#$startSecs = $endSecs - 28*24*3600;   # 28 days back
$startSecs = 1185926400; # 1 Aug 2007
#my $start_date = sql_date($startSecs);
#my $end_date = sql_date($endSecs);
$query =<<"EOQ";
DROP TABLE IF EXISTS $table_name
EOQ
    ;
$dbh->do($query);
$query=<<"EOQ";
create table $table_name
#explain
select net,count(distinct id) as N_sites,
 min(o.time) as min_time,max(o.time) as max_time,
 count(o.temp) as N_T,
 avg(o.temp)/10 as avg_T, avg(o.temp-m.temp)/10 as bias_T,
 std(o.temp-m.temp)/10 as std_T,
 count(o.ws) as N_S,
 avg(o.ws) as avg_S, avg(cast(o.ws-m.ws as signed)) as bias_S,
 std(cast(o.ws-m.ws as signed)) as std_S,
 sum(if(o.ws  > $S_for_DIR_limit &&
	m.ws > $S_for_DIR_limit,1,0)) as N_DIR,
 avg(if(o.ws  > $S_for_DIR_limit &&
	m.ws > $S_for_DIR_limit,
	if(cast(o.wd-m.wd as signed) between -180 and 180,
	   cast(o.wd-m.wd as signed),
	   if(cast(o.wd-m.wd as signed) > 180,
	      cast(o.wd-m.wd as signed)-360,
	      cast(o.wd-m.wd as signed)+360)),null)) as bias_DIR,
 std(if(o.ws  > $S_for_DIR_limit &&
	m.ws > $S_for_DIR_limit,
	if(cast(o.wd-m.wd as signed) between -180 and 180,
	   cast(o.wd-m.wd as signed),
	   if(cast(o.wd-m.wd as signed) > 180,
	      cast(o.wd-m.wd as signed)-360,
	      cast(o.wd-m.wd as signed)+360)),null)) as std_DIR,
std(sqrt(pow(o.ws,2)+pow(m.ws,2)-2*o.ws*m.ws*cos((o.wd-m.wd)/5729.58)))
    as std_W,
 avg(sqrt(pow(o.ws,2)+pow(m.ws,2)-2*o.ws*m.ws*cos((o.wd-m.wd)/5729.58)))
    as avg_W,
 sqrt(sum(pow(o.ws,2)+pow(m.ws,2)-2*o.ws*m.ws*cos((o.wd-m.wd)/5729.58))/count(o.wd))
    as rms_W,
 count(o.dp) as N_Td,
 avg(o.dp)/10 as avg_Td, avg(o.dp-m.dp)/10 as bias_Td,
 std(o.dp-m.dp)/10 as std_Td
 from dev2 as m,obs as o,stations 
 where m.sta_id = o.sta_id
 and m.sta_id = stations.id
 and m.fcst_len = 1
 and m.time = o.time
 and o.time >= $startSecs
 and o.time < $endSecs
 and hour(from_unixtime(o.time)) >= 18
 and hour(from_unixtime(o.time)) <= 21
 group by net
 having N_T > 100
EOQ
    ;
if($DEBUG) {
    print "query is $query\n";
}

my $sth = $dbh->do($query);
$dbh->disconnect();

sub sql_date {
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return sprintf("%4d-%2.2d-%2.2d %2.2d:%2.2d:%2.2d",
		   $year,$mon,$mday,$hour,$min,$sec);
}
  
