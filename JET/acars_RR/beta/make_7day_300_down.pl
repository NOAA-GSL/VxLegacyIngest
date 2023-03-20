#!/usr/bin/perl -T
use strict;

# PREAMBLE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

my $DEBUG=0;  # MAKE THIS NON-ZERO TO PRODUCE EXTRA DEBUG PRINTOUT

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
require "$thisDir/set_writer_acars_RR.pl";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $query = "";
my $sth;

my $table = "7day_300_down";

# for MySQL version 5, need to do this
# (although this is now done in the system's my.cnf file)
#
$query = qq[SET SQL_MODE='NO_UNSIGNED_SUBTRACTION'];
$dbh->do($query);

# get limits from the database
$query = qq|
    select S_for_DIR_limit
    from acars_RR.limits|;
my $sth_lim = $dbh->prepare($query);
$sth_lim->execute();
my($S_for_DIR_limit) = $sth_lim->fetchrow_array();
$sth_lim->finish();

my ($startSecs,$endSecs);
$endSecs = time()-7200;
$endSecs -= $endSecs % 86400; # start of today
$startSecs = $endSecs - 7*24*3600;   # 7 days back
my $start_date = sql_date($startSecs);
my $end_date = sql_date($endSecs);
$query =<<"EOQ";
DROP TABLE IF EXISTS $table
EOQ
    ;
$dbh->do($query);
$query=<<"EOQ";
create table $table select tail.xid,model,
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
 from acars,RR1h,tail where
 acars.aid = RR1h.aid
 and acars.xid = tail.xid
 and press > 3000
 and date >= '$start_date'
 and date < '$end_date'
 group by xid
 having N_T > 50;
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
  
