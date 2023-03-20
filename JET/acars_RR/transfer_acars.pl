#!/usr/bin/perl
#
#
#SBATCH -J ACARS_DB_transfer
#SBATCH --mail-user=jeffrey.a.hamilton@noaa.gov
#SBATCH --mail-type=FAIL
#SBATCH -A amb-verif
#SBATCH -n 1
#SBATCH -p service
#SBATCH -t 04:00:00
#SBATCH -D .
#SBATCH --mem=16G
#SBATCH -o tmp/ACARS_DB_transfer.oe%j
#

#
use strict;
use POSIX qw(strftime);

my $thisDir = $ENV{SLURM_SUBMIT_DIR};
unless($thisDir) {
    # we've been called locally instead of qsubbed
    use File::Basename; 
    my ($basename,$thisDir2) = fileparse($0);
    $thisDir = $thisDir2;
}
use Cwd 'chdir'; #use perl version so this isn't unix-dependentx
chdir ("$thisDir") ||
          die "xsCan't cd to $thisDir: $!\n";

my $n_args = @ARGV;
if($n_args <3) {
    print "usage: ./transfer_acars.pl <exp name> <startSecs> <endSecs> {<1= reprocess, 0=no reprocess>}.\n";
    die;
}
my $i_arg=0;
my $model = $ARGV[$i_arg++];
my $startSecs = abs($ARGV[$i_arg++]);
my $endSecs = $ARGV[$i_arg++];
my $reprocess = $ARGV[$i_arg++];
my $obs = "obs";
my ($query, $sth, $result);

my @fcst_lens = qw(0 1 3 6 9 12 24 36 48);
#my @fcst_lens = qw(0 1);

use DBI;
#set database connection parameters
$ENV{DBI_DSN} = "DBI:mysql:acars_RR2:wolphin.fsl.noaa.gov;mysql_local_infile=1";
$ENV{DBI_USER} = "wcron0_user";
$ENV{DBI_PASS} = "cohen_lee";
# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1, PrintWarn => 1});

print "$model\n";
 
for(my $valid_time=$startSecs;$valid_time<=$endSecs;$valid_time+=3600) {

if ($model eq "obs") {
$query = "show tables like 'acars'";
$result = $dbh->selectrow_array($query);
unless($result) {
   $query = "create table acars like acars_RR.acars";
   print "query: $query\n";
   $sth = $dbh->prepare($query);
   unless($sth->execute()) {
       print "Couldn't execute statement: " . $sth->errstr ." Exiting.\n";
   }
}
$query = "show tables like 'tail'";
$result = $dbh->selectrow_array($query);
unless($result) {
   $query = "create table tail like acars_RR.tail";
   print "query: $query\n";
   $sth = $dbh->prepare($query);
   unless($sth->execute()) {
       print "Couldn't execute statement: " . $sth->errstr ." Exiting.\n";
   }
}

print("\nPROCESSING observations valid at ".gmtime($valid_time)."\n");
if(!$reprocess && already_processed($obs,$valid_time,-99)) {
    print "ALREADY PROCESSED\n";
} else {
transfer_obs($valid_time);
}

} else {

foreach my $fcst_len (@fcst_lens) {

$query = "show tables like '$model%'";
$result = $dbh->selectrow_array($query);
unless($result) {
   $query = "create table $model like template";
   print "query: $query\n";
   $sth = $dbh->prepare($query);
   unless($sth->execute()) {
       print "Couldn't execute statement: " . $sth->errstr ." Exiting.\n";
   }
}

print("\nPROCESSING $model ${fcst_len}h forecast valid at ".gmtime($valid_time)."\n");
if(!$reprocess && already_processed($model,$valid_time,$fcst_len)) {
    print "ALREADY PROCESSED\n";
} else {
#transfer_model($model,$valid_time,$fcst_len);
transfer_sums($model,$valid_time,$fcst_len);
}
}
}
}

sub transfer_obs {
    print "transfer obs\n";
    my($valid_secs) = @_;
    my $valid_date = sql_date($valid_secs);
    my $query = <<"EOI"
insert ignore into acars (aid, date, xid, lat, lon, press, t, dir, s, hdg, ul, vx, mach, rh, ht, ap_id, up_dn, rh_unc, tas, source) select * from acars_RR.acars where date >= date_sub('$valid_date', interval 30 minute) and date < date_add('$valid_date', interval 30 minute);
EOI
;
    print "$query\n";
    $dbh->do($query);
}

sub transfer_model {
    print "transfer model\n";
    my($model,$valid_secs,$fcst_len) = @_;
    my $valid_date = sql_date($valid_secs);
        
    my $table = "${model}";
    my $old_table = "${model}_${fcst_len}";
 
    my $query = qq(show tables like "$table");
    my $result = $dbh->selectrow_array($query);
    #print "result is $result\n";
    unless($result) {
       # need to create the necessary tables
       $query = "create table $table like template";
       print "$query;\n";
       $dbh->do($query);
    }

    $dbh->do("use acars_RR");
    $query = qq(show tables like "$old_table");
    my $result = $dbh->selectrow_array($query);
    #print "result is $result\n";
    $dbh->do("use acars_RR2");
    unless(!$result) {
       $query = <<"EOI"
insert ignore into $table (aid,time,fcst_len,tf,dirf,sf,ulf,vxf,vdiff,rhf,htf)
select 
 ot.aid as aid,
 ot.time as time,
 $fcst_len as fcst_len,
 ot.tf as tf,
 ot.dirf as dirf,
 ot.sf as sf,
 ot.ulf as ulf,
 ot.vxf as vxf,
 ot.vdiff as vdiff,
 ot.rhf as rhf,
 ot.htf as htf
from
acars_RR.$old_table as ot
where 1 = 1
and ot.time = '$valid_date'
EOI
;
       print "$query;\n";
       $dbh->do($query);
    }
}

sub transfer_sums {

    print "transfer sums\n";
    my($model,$valid_secs,$fcst_len) = @_;
    my $valid_date = sql_date_only($valid_secs);
    my $valid_hour = sql_hour($valid_secs);

    my @regions = qw(Full HRRR);

    foreach my $region (@regions) {

    my $table = "${model}_${region}_sums";
    my $old_table = "${model}_${fcst_len}_${region}_sums";

    my $query = qq(show tables like "$table");
    my $result = $dbh->selectrow_array($query);
    #print "result is $result\n";
    unless($result) {
       # need to create the necessary tables
       $query = "create table $table like template_sums";
       print "$query;\n";
       $dbh->do($query);
    }

    $dbh->do("use acars_RR");
    $query = qq(show tables like "$old_table");
    my $result = $dbh->selectrow_array($query);
    #print "result is $result\n";
    $dbh->do("use acars_RR2");
    unless(!$result) {
       $query = <<"EOI"
replace into $table (date,hour,fcst_len,up_dn,mb10,N_dt,sum_ob_t,sum_dt,sum2_dt,N_dw,sum_ob_ws,sum_model_ws,sum_du,sum_dv,sum2_dw,N_dR,sum_ob_R,sum_dR,sum2_dR)
select 
 ot.date as date,
 ot.hour as hour,
 $fcst_len as fcst_len,
 ot.up_dn as up_dn,
 ot.mb10 as mb10,
 ot.N_dt as N_dt,
 ot.sum_ob_t as sum_ob_t,
 ot.sum_dt as sum_dt,
 ot.sum2_dt as sum2_dt,
 ot.N_dw as N_dw,
 ot.sum_ob_ws as sum_ob_ws,
 ot.sum_model_ws as sum_model_ws,
 ot.sum_du as sum_du,
 ot.sum_dv as sum_dv,
 ot.sum2_dw as sum2_dw,
 ot.N_dr as N_dr,
 ot.sum_ob_R as sum_ob_R,
 ot.sum_dR as sum_dR,
 ot.sum2_dR as sum2_dR
from
acars_RR.$old_table as ot
where 1 = 1
and ot.date = '$valid_date'
and ot.hour = $valid_hour
EOI
;
       print "$query;\n";
       $dbh->do($query);
    }
    }

}
	
sub sql_date {
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return sprintf("%4d-%2.2d-%2.2d %2.2d:%2.2d:%2.2d",
		   $year,$mon,$mday,$hour,$min,$sec);
}

sub sql_date_only {
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return sprintf("%4d-%2.2d-%2.2d",
                   $year,$mon,$mday);
}

sub sql_hour {
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return sprintf("%2.2d",
                   $hour);
}

sub already_processed {
    my($model,$valid_secs,$fcst_len) = @_;
    my $query;
    my $result = 0;
    my $valid_date = sql_date($valid_secs);
    if ($model eq "obs") {
       $query = <<"EOI"
select aid from acars where date >= 'date_sub($valid_date, interval 30 minute)' and date < 'date_add($valid_date, interval 30 minute)' limit 1
EOI
;
       print "$query\n";
       my $result = $dbh->selectrow_array($query);
    } else {
       my $table = "${model}_${fcst_len}";
       my $query = qq(show tables like "$table");
       my $check_result = $dbh->selectrow_array($query);
       print "check_result is $check_result\n";
       if ($result) {
          $query = <<"EOI"
select aid from $table where time >= date_sub('$valid_date', interval 30 minute) and time < date_add('$valid_date', interval 30 minute) limit 1
EOI
;
          print "$query\n";
          my $result = $dbh->selectrow_array($query);
          print "$result\n";
       }
       
   }
   print "result is $result\n";
   return($result);
} 
