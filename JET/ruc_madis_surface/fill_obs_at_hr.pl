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
my $last_time = time();
my $this_time;
my $dtime=0;
my $startSecs = $ARGV[0];
my $endSecs = $ARGV[1];
my $rows;

$query=<<"EOQ";
replace into obs_at_hr
(sta_id,time,temp,dp,slp,wd,ws,precip,vis100)
# describe
select o.sta_id,o.time,o.temp,o.dp,o.slp,o.wd,o.ws,o.precip,o.vis100
from Bak13a as m,obs as o
where 1=1
and m.time >= ? - 1800
and m.time < ? + 1800
and m.time = o.time
and m.sta_id = o.sta_id
EOQ
    ;
$sth = $dbh->prepare($query);

for(my $secs = $startSecs;$secs<=$endSecs;$secs+=3600) {
    $rows = $sth->execute($secs,$secs);
    my $time_str = gmtime($secs);
    print "loading $rows obs nearest $time_str into obs_at_hr\n";
}
