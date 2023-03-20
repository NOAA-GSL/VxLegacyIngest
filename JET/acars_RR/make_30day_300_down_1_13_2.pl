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
require "$thisDir/set_writer_acars_RR2.pl";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $query = "";
my $sth;

my $table = "30day_300_down_1_13_new";

# for MySQL version 5, need to do this
# (although this is now done in the system's my.cnf file)
#
$query = qq[SET SQL_MODE='NO_UNSIGNED_SUBTRACTION'];
$dbh->do($query);

# get limits from the database
$query = qq|
    select S_for_DIR_limit
    from acars_RR2.limits|;
my $sth_lim = $dbh->prepare($query);
$sth_lim->execute();
my($S_for_DIR_limit) = $sth_lim->fetchrow_array();
$sth_lim->finish();

my ($startSecs,$endSecs);
$endSecs = time()-7200;
$endSecs -= $endSecs % 86400; # start of today
$startSecs = $endSecs - 30*24*3600;   # 30 days back
my $start_date = sql_date($startSecs);
my $end_date = sql_date($endSecs);
my $start_day = substr($start_date,0,10);
my $end_day = substr($end_date,0,10);
$dbh->do("drop table if exists $table");
$query=<<"EOQ";
create table $table
(
  `xid` smallint(6) unsigned NOT NULL DEFAULT '0',
  `model` varchar(255) DEFAULT NULL,
  `min_d` datetime DEFAULT NULL,
  `max_d` datetime DEFAULT NULL,
  `N_T` bigint(21) NOT NULL DEFAULT '0',
  `avg_T` double DEFAULT NULL,
  `bias_T` double DEFAULT NULL,
  `std_T` double DEFAULT NULL,
  `N_S` bigint(21) NOT NULL DEFAULT '0',
  `avg_S` double DEFAULT NULL,
  `bias_S` double DEFAULT NULL,
  `std_S` double DEFAULT NULL,
  `bias_DIR` double DEFAULT NULL,
  `std_DIR` double DEFAULT NULL,
  `std_W` double DEFAULT NULL,
  `avg_W` double DEFAULT NULL,
  `rms_W` double DEFAULT NULL,
  `N_RH` bigint(21) NOT NULL DEFAULT '0',
  `avg_RH` double DEFAULT NULL,
  `bias_RH` double DEFAULT NULL,
  `std_RH` double DEFAULT NULL,
  `min_s` int(11) DEFAULT NULL,
  `max_s` int(11) DEFAULT NULL
)       
select tail.xid,model,
 min(date) as min_d,max(date) as max_d,
 count(t) as N_T,
 avg(t)/100 as avg_T, avg(t-tf)/100 as bias_T,
 std(t-tf)/100 as std_T,
 count(s) as N_S,
 avg(s)/100 as avg_S, avg(s-sf)/100 as bias_S,
 std(s-sf)/100 as std_S,
 avg(if(s/100  > $S_for_DIR_limit &&
	sf/100 > $S_for_DIR_limit,
	if((dir-dirf)/100 between -180 and 180,
	   (dir-dirf)/100,
	   if((dir-dirf)/100 > 180,
	      (dir-dirf)/100-360,
	      (dir-dirf)/100+360)),null)) as bias_DIR,
 std(if(s/100  > $S_for_DIR_limit &&
	sf/100 > $S_for_DIR_limit,
	if((dir-dirf)/100 between -180 and 180,
	   (dir-dirf)/100,
	   if((dir-dirf)/100 > 180,
	      (dir-dirf)/100-360,
	      (dir-dirf)/100+360)),null)) as std_DIR,
 std(sqrt(pow(s,2)+pow(sf,2)-2*s*sf*cos((dir-dirf)/5729.58)))/100
    as std_W,
 avg(sqrt(pow(s,2)+pow(sf,2)-2*s*sf*cos((dir-dirf)/5729.58)))/100
    as avg_W,
 sqrt(sum(pow(s,2)+pow(sf,2)-2*s*sf*cos((dir-dirf)/5729.58))/count(dir))/100
    as rms_W,
 count(rh) as N_RH,
 avg(rh) as avg_RH, avg(rh-rhf) as bias_RH,
 std(rh-rhf) as std_RH,
 unix_timestamp(min(date)) as min_s,
 unix_timestamp(max(date)) as max_s
 from
    acars as o force index(date)
    JOIN RAP_OPS_iso as m 
    JOIN tail
 on
 (o.aid = m.aid and o.xid = tail.xid)
 where 1=1	      
 and press > 3000
 and m.fcst_len = 1
 and time >= '$start_date'
 and time < '$end_date'
 and date >= '$start_day'
 and date <= '$end_day'
 and hour(date_add(date, interval 30 minute))   IN(1,13)
 group by xid
 having N_T > 50
 order by null
EOQ
    ;
if($DEBUG) {
print "query is $query\n";
}
my $sth = $dbh->do($query);
my $info = $dbh->{'mysql_info'};
print "$info\n";

my $old_table = $table;
$old_table =~ s/_new//;
$query =<<"EOQ";
DROP TABLE IF EXISTS $old_table
EOQ
    ;
print "$query\n";
$dbh->do($query);

$query = "alter table $table rename as $old_table";
print "$query\n";
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
  
