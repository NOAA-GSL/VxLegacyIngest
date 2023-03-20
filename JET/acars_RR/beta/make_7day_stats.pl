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

#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";
#$thisDir = $ENV{PWD};

# END OF PREAMBLE ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

use DBI;
use Time::Local;

#connect
require "$thisDir/set_writer_acars_RR.pl";
require "$thisDir/update_bad_tails.pl";
$ENV{DBI_USER} = "xxxx";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1,HandleError => \&handle_error}) or
    handle_error(DBI->errstr);
my $query = "";
my $sth;

# for MySQL version 5, need to do this
$query = qq[SET SQL_MODE='NO_UNSIGNED_SUBTRACTION'];
$dbh->do($query);
$query = qq[SET  time_zone = '+0:00'];
$dbh->do($query);

# get limits from the database
$query = qq|
    select S_for_DIR_limit
    from acars_RR.limits|;
my $sth_lim = $dbh->prepare($query);
$sth_lim->execute();
my($S_for_DIR_limit) = $sth_lim->fetchrow_array();
$sth_lim->finish();

my $days_ago = $ARGV[0] || 7;
print("processing data for the last $days_ago days\n");

my ($startSecs,$endSecs);
$endSecs = time()-7200;
$endSecs -= $endSecs % 86400; # start of today
$startSecs = $endSecs - $days_ago*24*3600;   
my $start_date = sql_date($startSecs);
my $end_date = sql_date($endSecs);
my $start_day = substr($start_date,0,10);
my $end_day = substr($end_date,0,10);
my $new_table = "${days_ago}day_new";
my $old_table = $new_table;
$old_table =~ s/_new//;
$query = "drop table if exists $new_table";
if($DEBUG) {print "$query\n";}
$dbh->do($query);
$query=<<"EOQ";
create table $new_table
 ( `xid` smallint(6) unsigned NOT NULL DEFAULT '0',
  `model` varchar(255) DEFAULT NULL,
  `min_d` datetime DEFAULT NULL,
  `max_d` datetime DEFAULT NULL,
  `N_T` bigint(21) NOT NULL DEFAULT '0',
  `avg_T` float DEFAULT NULL,
  `bias_T` float DEFAULT NULL,
  `std_T` float DEFAULT NULL,
  `N_S` bigint(21) NOT NULL DEFAULT '0',
  `avg_S` float DEFAULT NULL,
  `bias_S` float DEFAULT NULL,
  `std_S` float DEFAULT NULL,
  `bias_DIR` float DEFAULT NULL,
  `std_DIR` float DEFAULT NULL,
  `std_W` float DEFAULT NULL,
  `avg_W` float DEFAULT NULL,
  `rms_W` float DEFAULT NULL,
  `N_RH` bigint(21) NOT NULL DEFAULT '0',
  `avg_RH` float DEFAULT NULL,
  `bias_RH` float DEFAULT NULL,
  `std_RH` float DEFAULT NULL,
  `min_s` int(10) DEFAULT NULL,
  `max_s` int(10) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1
# describe partitions
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
    acars as o
    JOIN RAP_iso_1 as m 
    JOIN tail
 on
 (o.aid = m.aid and o.xid = tail.xid)
 where 1=1	      
 and press <= 10000
 and lat != 0    # correct a TEMPORARY bug with bad data with NCAR EDR data
 and time >= '$start_date'
 and time < '$end_date'
 and date >= '$start_day'
 and date <= '$end_day'
 group by xid
 having N_T > 200
 order by null
EOQ
    ;
if($DEBUG) {
    print "query is $query\n";
}

my $start_time = time();
my $sth = $dbh->do($query);
my $end_time = time();
my $query_time = $end_time - $start_time;
my $info = $dbh->{mysql_info};
print_warn($dbh);
my $time_str = gmtime($end_time);
	      
$query =<<"EOQ";
DROP TABLE IF EXISTS $old_table
EOQ
	      ;
#print "$query\n";
$dbh->do($query);
$query = "alter table $new_table rename as $old_table";
#print "$query\n";
$dbh->do($query);
$query = "select min(min_d),max(max_d) from ${days_ago}day";
my @ary = $dbh->selectrow_array($query);
open(LOG,">>query_times.txt");
print "$old_table: $time_str $info loaded in $query_time seconds\n";
print "\tdata from $ary[0] to $ary[1]\n";
print LOG "$old_table: $time_str $info loaded in $query_time seconds\n";
print LOG "\tdata from $ary[0] to $ary[1]\n";

# update bad tails 
update_bad_tails($dbh,$days_ago,$DEBUG);
	      
close(LOG);
$dbh->disconnect();

sub sql_date {
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return sprintf("%4d-%2.2d-%2.2d %2.2d:%2.2d:%2.2d",
		   $year,$mon,$mday,$hour,$min,$sec);
}
sub print_warn {
    my $dbh = shift;
    my $warnings = $dbh->selectall_arrayref('SHOW WARNINGS');
    for my $row (@$warnings) {
	print "@{$row}\n";
    }
}

sub handle_error {
    my $message = shift;
    my $time_str = gmtime(time());
    print "$basename, $time_str: $message\n";
    open(LOG,">>query_times.txt");
    print LOG "$basename, $time_str: $message\n";
    close(LOG);
    exit(1); #stop the program
}  
