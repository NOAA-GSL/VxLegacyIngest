#!/usr/bin/perl
#
#PBS -d .                                                                                                           
#PBS -N a_r_st3
#PBS -A amb-verif                                                                                                       
#PBS -l procs=1                                                                                                     
#PBS -l partition=tjet:ujet:sjet:vjet:xjet                                                                                              
#PBS -q service                                                                                                     
#PBS -l walltime=01:00:00                                                                                           
#PBS -l vmem=16G                                                                                                     
#PBS -e tmp/                                                                                                        
#PBS -o tmp/
#
use strict;
my $thisDir = $ENV{PBS_O_WORKDIR};
my $qsubbed=1;
unless($thisDir) {
    # we've been called locally instead of qsubbed
    $qsubbed=0;
    use File::Basename; 
    my ($basename,$thisDir2) = fileparse($0);
    $thisDir = $thisDir2;
}
my $output_id = $ENV{PBS_JOBID} || $$;

my $DEBUG=1;
use DBI;


#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";
$thisDir = $ENV{PWD};

#set database connection parameters
$ENV{DBI_DSN} = "DBI:mysql::wolphin.fsl.noaa.gov";
$ENV{DBI_USER} = "UA_realtime";
$ENV{DBI_PASS} = "newupper";

$ENV{model_sounding_file} = "tmp/model_sounding.$$.tmp";

# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $sth;
my $query="";

$query = "use surfrad2";
$dbh->do($query);
$query = qq{show tables like "%WFIP2"};
$sth = $dbh->prepare($query);
$sth->execute();
my $old_table;
$sth->bind_columns(\$old_table);
while($sth->fetch()) {
    print "table is $old_table\n";
    $query = "create table surfrad3.$old_table like surfrad3.RAP_130";
    print "$query\n";
    $dbh->do($query);
    my @scales = (13,26,52);
    foreach my $scale (@scales) {
	$query=<<"EOI"
replace into surfrad3.$old_table (id,secs,fcst_len,scale,dswrf)
select id,secs,fcst_len,'$scale',dswrf$scale
from surfrad2.$old_table
EOI
;
	print "$query\n";
	my $rows = $dbh->do($query);
	print "$rows rows inserted\n";
    } # each scale
} # each table

sub sql_datetime {
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return sprintf("%4d-%2.2d-%2.2d %2.2d:%2.2d:%2.2d",
		   $year,$mon,$mday,$hour,$min,$sec);
}

sub sql_date_hour {
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return (sprintf("%4d-%2.2d-%2.2d",$year,$mon,$mday),$hour);
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
    
