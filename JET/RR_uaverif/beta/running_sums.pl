#!/usr/bin/perl
use strict;
my $thisDir = $ENV{SLURM_SUBMIT_DIR};
my $qsubbed=1;
unless($thisDir) {
    # we've been called locally instead of qsubbed
    $qsubbed=0;
    use File::Basename; 
    my ($basename,$thisDir2) = fileparse($0);
    $thisDir = $thisDir2;
}
my $output_id = $ENV{SLURM_JOB_ID} || $$;

my $DEBUG=1;
use DBI;

#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";
$thisDir = $ENV{PWD};

#set database connection parameters
$ENV{DBI_DSN} = "DBI:mysql:ruc_ua:wolphin.fsl.noaa.gov";
$ENV{DBI_USER} = "UA_realtime";
$ENV{DBI_PASS} = "newupper";

# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $sth;
my $query="";

$|=1;  #force flush of buffers after each print

my $start_time = 1572566400; # Fri 1 Nov 2019 00:00:00
my $end_time = 1589328000; # Wed 13 May 2020 00:00:00
for(my $valid_time=$start_time;$valid_time <=$end_time;$valid_time+=24*3600) {
    my $sql_date = sql_date($valid_time);
    $query=<<"EOI"
insert into RAP_OPS_130_dw_10_21 (min_date,max_date,fcst_len,av_o_ws_21,N_21,N_10_21,fract_21)
select
min(b1.date) as min_date
,max(b1.date) as max_date
,b1.fcst_len as fcst_len
,round(avg(o_ws)/100,1) as av_o_ws_21
,count(b1.dw) as N_21
,sum(if(b1.dw > 1000,1,0)) as N_10_21
,sum(if(b1.dw > 1000,1,0)) /count(*) as fract_21
from RAP_OPS_130_dw b1
where 1=1
and b1.fcst_len = 12
and b1.hour = 0
and datediff('$sql_date',b1.date) < 21
and datediff('$sql_date',b1.date) >= 0
group by '1'
EOI
;
  print("$query ... ");
$sth = $dbh->prepare($query);
my $rows = $sth->execute();
print("$rows rows inserted\n");
}
print "NORMAL TERMINATION\n";


sub sql_datetime {
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return sprintf("%4d-%2.2d-%2.2d %2.2d:%2.2d:%2.2d",
		   $year,$mon,$mday,$hour,$min,$sec);
}

sub sql_date{
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return (sprintf("%4d-%2.2d-%2.2d",$year,$mon,$mday));
}

sub raobs_loaded($valid_time) {
    my($valid_time) = @_;
    my($valid_day,$valid_hour) = sql_date_hour($valid_time);
    my $query =<<"EOI"
select count(*) from ruc_ua.RAOB
where 1=1
and press = 500
and hour = $valid_hour
and date = '$valid_day'
EOI
;
    #print "query is $query\n";
    my $sth = $dbh->prepare($query);
    $sth->execute();
    my($n);
    $sth->bind_columns(\$n);
    $sth->fetch();
    #print "n returned is $n\n";
    my $result=0;
    if($n > 400) {
	$result = $n;
    }
    return $result;
}
    
