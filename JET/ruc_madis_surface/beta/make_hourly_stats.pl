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
#$ -M William.R.Moninger@noaa.gov
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
my $n_days = $ARGV[0] || 1;
my $back_end_days = $ARGV[1] || 0; 
my $n_rows;
my $table;

my ($startSecs,$endSecs);
$endSecs = time()-7200;
$endSecs -= $endSecs % 86400; # start of today
$endSecs -= $back_end_days*24*3600;
$startSecs = $endSecs - $n_days*24*3600;   # n_days earlier

$query =<<"EOI";
replace into Bak13_metar_RUC
(valid_day,hour,fcst_len,N_dt,sum_ob_t,sum_dt,sum2_dt,
 N_dw,sum_ob_ws,sum_model_ws,sum_du,sum_dv,sum2_dw,
 N_dtd,sum_ob_td,sum_dtd,sum2_dtd)
select floor((m.time+1800)/(24*3600))*(24*3600) as valid_day
,floor(((m.time+1800)%(24*3600))/3600) as hour
,m.fcst_len
,count(o.temp - m.temp) as N_dt
,sum(if(m.temp is not null,o.temp,null))/10 as sum_ob_t
,sum(o.temp - m.temp)/10 as sum_dt
,sum(pow(o.temp - m.temp,2))/100 as sum2_dt
,count(o.wd + m.wd) as N_dw
,sum(if(m.ws is not null,o.ws,null)) as sum_ob_ws
,sum(if(o.ws is not null,m.ws,null)) as sum_model_ws
,sum(o.ws*sin(o.wd/57.2658) - m.ws*sin(m.wd/57.2658)) as sum_du
,sum(o.ws*cos(o.wd/57.2658) - m.ws*cos(m.wd/57.2658)) as sum_dv
,sum(pow(o.ws,2)+pow(m.ws,2)-  2*o.ws*m.ws*cos((o.wd-m.wd)/57.2958)) as sum2_dw
,count(o.dp - m.dp) as N_dtd
,sum(if(m.dp is not null,o.dp,null))/10 as avg_ob_dp
,sum(o.dp - m.dp)/10 as sum_dtd
,sum(pow(o.dp - m.dp,2))/100 as sum2_dtd
from obs as o,Bak13 as m,stations as s
where 1=1
and o.sta_id = m.sta_id
and o.sta_id = s.id
and net = 'METAR'
and o.time = m.time
and o.time >= $startSecs - 1800
and o.time <= $endSecs - 1800
group by valid_day,hour,fcst_len
EOI
print "$query";
$dbh->do($query);


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
    if(-M $file > .01) {
	print "unlinking $file\n";
	unlink "$file" || print "Can't unlink $file $!\n";
    }
}
closedir DIR;
print "NORMAL TERMINATION\n";
