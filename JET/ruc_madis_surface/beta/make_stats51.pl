#!/usr/bin/perl
#PBS -d .
#PBS -N madis51_hrrr_stats 
#PBS -M verif-amb.gsd@noaa.gov
#PBS -m a
#PBS -A amb-verif
#PBS -l procs=1
#PBS -l partition=vjet
#PBS -q service 
#PBS -l walltime=03:00:00
#PBS -l vmem=1G

#PBS -e tmp/
#PBS -o tmp/
#
use strict;
my $thisDir = $ENV{PBS_O_WORKDIR};
unless($thisDir) {
    # we've been called locally instead of qsubbed
    use File::Basename; 
    my ($basename,$thisDir2) = fileparse($0);
    $thisDir = $thisDir2;
    print "dollar 0 is $0\n";
    print "thisDir is $thisDir\n";
}
#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";
print "current directory is $ENV{PWD}\n";

my $DEBUG=1;  # MAKE THIS NON-ZERO TO PRODUCE EXTRA DEBUG PRINTOUT

use lib "./";

use DBI;
use Time::Local;

#connect
require "$thisDir/set_connection3.pl";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
$dbh->do("use madis3");
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

# debugging
# $endSecs =  1286755200;
# $startSecs = 1286712000;

# account for gaps. Make sure we have enough 1h model runs 
# to make up the number of days requested;

my $n_runs = 24*$n_days;
print "getting start time that will include $n_runs runs\n";
$query =<<"EOI"
select valid_day
from surface_sums.HRRR_metar_v2_ALL_HRRR
where 1=1
#and hour IN(18,19,20,21)
and valid_day <= $endSecs
and fcst_len = 1
order by valid_day desc,hour desc
limit  $n_runs
EOI
    ;
print "$query;\n";
$sth = $dbh->prepare($query);
$sth->execute();
$sth->bind_col( 1, \$startSecs );
while($sth->fetch()) {};
print "startSecs is $startSecs\n";

$table = "HRRR_short";
# no need to drop it if it's a temporary table.
#$query = "drop table if exists $table\n";
#print "$query;\n";
#$dbh->do($query);

$query =<<"EOQ";
create temporary table $table
# describe partitions
select net,name,sta_id,time,temp,dp,wd,ws
from HRRRqp1f as m,stations as s    #, (emacs coloration)
where 1=1
and m.sta_id = s.id
#and fcst_len = 1
and time >= $startSecs
and time < $endSecs
EOQ
    ;
print "$query;\n";
$n_rows = $dbh->do($query);
$this_time = time();
my $begin_time = $this_time;
$dtime = $this_time - $last_time;
print "... took $dtime secs\n\n";
$last_time = $this_time;

$table = "obs_short";
#$query = "drop table if exists $table\n";
#print "$query;\n";
#$dbh->do($query);

$query =<<"EOQ";
create temporary table $table (
sta_id   mediumint(8) unsigned,
time     int(10) unsigned,
temp     smallint(6),
dp       smallint(6),
slp      smallint(6),
wd       smallint(6),
ws       smallint(5) unsigned,
wg       smallint(5) unsigned,
precip   smallint(5) unsigned,
vis100   smallint(5) unsigned
)
# describe partitions
select o.sta_id,o.time,o.temp,o.dp,o.slp,o.wd,
o.ws,o.wg,o.precip,o.vis100
from obs as o,HRRR_short as m
where 1=1
and m.time = o.time
and m.sta_id = o.sta_id
and o.time >= $startSecs
and o.time < $endSecs
EOQ
    ;
print "$query;\n";
$n_rows = $dbh->do($query);
$this_time = time();
$dtime = $this_time - $last_time;
print "... took $dtime secs\n\n";
$last_time = $this_time;

$query = "alter table $table add index time_id (time,sta_id)";
print "$query;\n";
$n_rows = $dbh->do($query);
$this_time = time();
$dtime = $this_time - $last_time;
print "$n_rows rows... took $dtime secs\n\n";
$last_time = $this_time;

$query = "analyze table $table";
print "$query;\n";
$n_rows = $dbh->do($query);
$this_time = time();
$dtime = $this_time - $last_time;
print "$n_rows rows... took $dtime secs\n\n";
$last_time = $this_time;

$table = "HRRR_net_${n_days}day";
$query = "drop table if exists $table\n";
print "$query;\n";
$dbh->do($query);

$query=<<"EOQ"
create table $table
(
 net varchar(15) not null,
N_sites int unsigned not null,
min_time int not null,
max_time int not null,
N_T int unsigned not null,
avg_T float comment 'in farenheit',
bias_T float comment 'in farenheit',
std_T float comment 'in farenheit',
N_S int unsigned not null,
avg_S float comment 'in mph',
bias_S float comment 'in mph',
std_S float comment 'in mph',
N_DIR int unsigned,
bias_DIR float,
std_DIR float,
std_W float comment 'in mph',
avg_W float comment 'in mph',
rms_W float comment 'in mph',
N_Td int,
avg_Td float comment 'in farenheit',
bias_Td float comment 'in farenheit',
std_Td float comment 'in farenheit'
)
EOQ
    ;
print "$query";
$n_rows = $dbh->do($query);
$this_time = time();
$dtime = $this_time - $last_time;
print "... took $dtime secs\n\n";
$last_time = $this_time;

$query =<<"EOQ"
insert into $table (net,N_sites,min_time,max_time,N_T,avg_T,bias_T,std_T,
		    N_S,avg_S,bias_S,std_S,N_DIR,bias_DIR,std_DIR,std_W,avg_W,rms_W,
		    N_Td,avg_Td,bias_Td,std_Td)
# describe partitions
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
 from HRRR_short as m,obs_short as o    #, (colaration)
 where 1=1
 and m.sta_id = o.sta_id
 and m.time = o.time
 and o.time >= $startSecs
 and o.time < $endSecs
 #and hour(from_unixtime(o.time)) >= 18
 #and hour(from_unixtime(o.time)) <= 21
 group by net
 having (N_T > 100 or N_S > 100 or N_Td > 100)
 order by null  # avoid a filesort (but one remains--it may not take much time)
EOQ
    ;
print "$query;\n";
$n_rows = $dbh->do($query);
$this_time = time();
$dtime = $this_time - $last_time;
print "$n_rows rows... took $dtime secs\n\n";
$last_time = $this_time;

$table = "HRRR_${n_days}day";
$query = "drop table if exists $table\n";
print "$query";
$dbh->do($query);

$query =<<"EOQ";
create table $table
(
 sta_id mediumint not null,
 name char(5) not null,
 net varchar(20),
min_time int not null comment 'secs since 1/11970',
max_time int not null comment 'secs since 1/11970',
N_T int unsigned not null,
avg_T float comment 'in farenheit',
bias_T float comment 'in farenheit',
std_T float comment 'in farenheit',
N_S int unsigned not null,
avg_S float comment 'in mph',
bias_S float comment 'in mph',
std_S float comment 'in mph',
N_DIR int unsigned,
bias_DIR float,
std_DIR float,
std_W float comment 'in mph',
avg_W float comment 'in mph',
rms_W float comment 'in mph',
N_Td int,
avg_Td float comment 'in farenheit',
bias_Td float comment 'in farenheit',
std_Td float comment 'in farenheit'
)
EOQ
    ;
print "$query";
$n_rows = $dbh->do($query);
$this_time = time();
$dtime = $this_time - $last_time;
print "$n_rows rows... took $dtime secs\n\n";
$last_time = $this_time;

$query =<<"EOQ"
insert into $table (sta_id,name,net,min_time,max_time,N_T,avg_T,bias_T,std_T,
		    N_s,avg_S,bias_S,std_S,N_DIR,bias_DIR,std_DIR,std_W,avg_W,rms_W,
		    N_Td,avg_Td,bias_Td,std_Td)
# describe partitions
select o.sta_id,name,net,
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
 from HRRR_short as m,obs_short as o                    #, ( emacs coloration)
 where m.sta_id = o.sta_id
 #and o.sta_id = stations.id
 and m.time = o.time
 and o.time >= $startSecs
 and o.time < $endSecs
 #and hour(from_unixtime(o.time)) >= 18
 #and hour(from_unixtime(o.time)) <= 21
 group by m.sta_id                                                     #. (emacs coloration)
 having (N_S > 20 or N_Td > 20 or N_S > 20)
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
    if(-M $file > 1.0) {
	print "unlinking $file\n";
	unlink "$file" || print "Can't unlink $file $!\n";
    }
}
closedir DIR;
$this_time = time();
if(system("./make_mesonet_uselist_HRRR.3.pl")) {
    print"couldn't make mesonet uselist for HRRR: $!\n";
} else {
    $dtime = $this_time - $last_time;
    print "making HRRR mesonet uselist took $dtime secs\n\n";
}
$last_time = $this_time;
if(system("./make_mesonet_uselist_RTMA.pl")) {
    print "couldn't make mesonet uselist for RTMA: $!\n";
} else {
    $dtime = $this_time - $last_time;
    print "making RTMA mesonet uselist took $dtime secs\n\n";
}

$this_time = time();
$dtime = $this_time - $begin_time;
print "NORMAL TERMINATION ... took $dtime secs\n";
