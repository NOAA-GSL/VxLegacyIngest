#!/usr/bin/perl
#
#  Set the name of the job.
#$ -N madis_ruc_stats
#  Make sure that the .e and .o file arrive in the working directory
#$ -cwd
#
#  Set the account
#$ -A wrfruc
#
#  Ask for 1 cpus of type service
#$ -pe service 1
#
#  My code is re-runnable
#$ -r y
#
# send mail on abort, end
#$ -m a
#$ -M Susan.R.Sahm@noaa.gov
#
#  The max walltime 
#$ -l h_rt=01:00:00
#
#$ -e tmp/
#$ -o tmp/
#
use strict;
my $thisDir = $ENV{SGE_O_WORKDIR};
unless($thisDir) {
    # we've been called locally instead of qsubbed
    use File::Basename; 
    my ($basename,$thisDir2) = fileparse($0);
    $thisDir = $thisDir2;
}

my $DEBUG=1;  # MAKE THIS NON-ZERO TO PRODUCE EXTRA DEBUG PRINTOUT

use lib "./";

use DBI;
use Time::Local;

#connect
require "$thisDir/set_connection3.pl";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $query = "";
my $sth;
my $last_time = time();
my $this_time;
my $dtime=0;
my $n_days = $ARGV[0];
my $back_end_days = $ARGV[1] || 0; 
my $n_rows;
my $table;
print "Calculating surface stats for $n_days days, ending $back_end_days ago\n\n";

# get limits from the database
$query = qq|
    select S_for_DIR_limit
    from limits|;
my $sth_lim = $dbh->prepare($query);
$sth_lim->execute();
my($S_for_DIR_limit) = $sth_lim->fetchrow_array();
$sth_lim->finish();

my ($startSecs,$endSecs);
$endSecs = time()-7200;
$endSecs -= $endSecs % 86400; # start of today
$endSecs -= $back_end_days*24*3600;
$startSecs = $endSecs - $n_days*24*3600;   # n_days earlier

$table = "Bak13_short";
$query = "drop table if exists $table\n";
print "$query";
$dbh->do($query);

$query =<<"EOQ";
create table $table
select sta_id,time,temp,dp,wd,ws
from Bak13a
where 1=1
and fcst_len = 1
and time >= $startSecs
and time < $endSecs
EOQ
    ;
print "$query";
$n_rows = $dbh->do($query);
$this_time = time();
$dtime = $this_time - $last_time;
print "$n_rows rows... took $dtime secs\n\n";
$last_time = $this_time;

$table = "Bak13_net_short";
$query = "drop table if exists $table\n";
print "$query";
$dbh->do($query);

$query =<<"EOQ";
create table $table
#explain
select net,sta_id,time,temp,dp,wd,ws
from Bak13_short,stations
where 1=1
and stations.id = Bak13_short.sta_id
EOQ
    ;
print "$query";
$n_rows = $dbh->do($query);
$this_time = time();
$dtime = $this_time - $last_time;
print "$n_rows rows... took $dtime secs\n\n";
$last_time = $this_time;

$table = "Bak13_net_${n_days}day";
$query = "drop table if exists $table\n";
print "$query";
$dbh->do($query);

$query=<<"EOQ";
create table $table
(
 net varchar(15) not null,
N_sites int unsigned not null,
min_time int not null,
max_time int not null,
N_T int unsigned not null,
avg_T float,
bias_T float,
std_T float,
N_S int unsigned not null,
avg_S float,
bias_S float,
std_S float,
N_DIR int unsigned,
bias_DIR float,
std_DIR float,
std_W float,
avg_W float,
rms_W float,
N_Td int,
avg_Td float,
bias_Td float,
std_Td float
)
#explain
select net,count(distinct m.sta_id) as N_sites
 ,min(o.time) as min_time,max(o.time) as max_time
 ,count(o.temp) as N_T
 ,avg(o.temp)/10 as avg_T, avg(o.temp-m.temp)/10 as bias_T
 ,std(o.temp-m.temp)/10 as std_T
 ,count(o.ws) as N_S
 ,avg(o.ws) as avg_S, avg(cast(o.ws-m.ws as signed)) as bias_S
 ,std(cast(o.ws-m.ws as signed)) as std_S
 ,sum(if(o.ws  > 5 &&
        m.ws > 5,1,0)) as N_DIR
 ,avg(if(o.ws  > 5 &&
        m.ws > 5,
        if(cast(o.wd-m.wd as signed) between -180 and 180,
           cast(o.wd-m.wd as signed),
           if(cast(o.wd-m.wd as signed) > 180,
              cast(o.wd-m.wd as signed)-360,
              cast(o.wd-m.wd as signed)+360)),null)) as bias_DIR
 ,std(if(o.ws  > 5 &&
        m.ws > 5,
        if(cast(o.wd-m.wd as signed) between -180 and 180,
           cast(o.wd-m.wd as signed),
           if(cast(o.wd-m.wd as signed) > 180,
              cast(o.wd-m.wd as signed)-360,
              cast(o.wd-m.wd as signed)+360)),null)) as std_DIR
 ,std(sqrt(pow(o.ws,2)+pow(m.ws,2)-2*o.ws*m.ws*cos((o.wd-m.wd)/57.2958)))
    as std_W
 ,avg(sqrt(pow(o.ws,2)+pow(m.ws,2)-2*o.ws*m.ws*cos((o.wd-m.wd)/57.2958)))
    as avg_W
 ,sqrt(sum(pow(o.ws,2)+pow(m.ws,2)-2*o.ws*m.ws*cos((o.wd-m.wd)/57.2958))/count(o.wd))
    as rms_W
 ,count(o.dp) as N_Td
 ,avg(o.dp)/10 as avg_Td, avg(o.dp-m.dp)/10 as bias_Td
 ,std(o.dp-m.dp)/10 as std_Td
 from Bak13_net_short as m,obs_at_hr as o
 where 1=1
 and m.sta_id = o.sta_id
 and m.time = o.time
 group by net
 having N_T > 100
 order by null  # avoid a filesort (but one remains--it may not take much time)
EOQ
    ;
print "$query";
$n_rows = $dbh->do($query);
$this_time = time();
$dtime = $this_time - $last_time;
print "$n_rows rows... took $dtime secs\n\n";
$last_time = $this_time;

$table = "Bak13_${n_days}day";
$query = "drop table if exists $table\n";
print "$query";
$dbh->do($query);

$query =<<"EOQ";
create table $table
(
 sta_id mediumint not null,
 name char(5) not null,
 net varchar(20),
min_time int not null,
max_time int not null,
N_T int unsigned not null,
avg_T float,
bias_T float,
std_T float,
N_S int unsigned not null,
avg_S float,
bias_S float,
std_S float,
N_DIR int unsigned,
bias_DIR float,
std_DIR float,
std_W float,
avg_W float,
rms_W float,
N_Td int,
avg_Td float,
bias_Td float,
std_Td float
)
#explain
select o.sta_id,name,stations.net,
 min(o.time) as min_time,max(o.time) as max_time,
 count(o.temp) as N_T,
 avg(o.temp)/10 as avg_T, avg(o.temp-m.temp)/10 as bias_T,
 std(o.temp-m.temp)/10 as std_T,
 count(o.ws) as N_S,
 avg(o.ws) as avg_S,
 avg(cast(o.ws-m.ws as signed)) as bias_S,
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
std(sqrt(pow(o.ws,2)+pow(m.ws,2)-2*o.ws*m.ws*cos((o.wd-m.wd)/57.2958)))
    as std_W,
 avg(sqrt(pow(o.ws,2)+pow(m.ws,2)-2*o.ws*m.ws*cos((o.wd-m.wd)/57.2958)))
    as avg_W,
 sqrt(sum(pow(o.ws,2)+pow(m.ws,2)-2*o.ws*m.ws*cos((o.wd-m.wd)/57.2958))/count(o.wd))
    as rms_W,
 count(o.dp) as N_Td,
 avg(o.dp)/10 as avg_Td, avg(o.dp-m.dp)/10 as bias_Td,
 std(o.dp-m.dp)/10 as std_Td
 from Bak13_net_short as m,obs_at_hr as o,stations
 where m.sta_id = o.sta_id
 and o.sta_id = stations.id
 and m.time = o.time
 #and hour(from_unixtime(o.time)) >= 18
 #and hour(from_unixtime(o.time)) <= 21
 group by m.sta_id
 having N_S > 30
 order by null
EOQ
    ;
print "$query";
$n_rows = $dbh->do($query);
$this_time = time();
$dtime = $this_time - $last_time;
print "$n_rows rows... took $dtime secs\n\n";
$last_time = $this_time;

#finish up
$dbh->disconnect();
# clean up tmp directory
opendir(DIR,"tmp") ||
    die "cannot open tmp/: $!\n";
my @allfiles = grep !/^\.\.?$/,readdir DIR;
foreach my $file (@allfiles) {
    $file = "tmp/$file";
    #print "file is $file\n";
    # untaint
    $file =~ /(.*)/;
    $file = $1;
    if(-M $file > .5) {
	print "unlinking $file\n";
	unlink "$file" || print "Can't unlink $file $!\n";
    }
}
closedir DIR;
print "NORMAL TERMINATION\n";