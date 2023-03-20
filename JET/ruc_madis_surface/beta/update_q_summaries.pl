#!/usr/bin/perl
use strict;
my $DEBUG=1;
use Time::Local;
use DBI;
$|=1;  #force flush of buffers after each print
open (STDERR, ">&STDOUT") || die "can't dup stdout ($!)\n";
$ENV{'PATH'}="/bin";
$ENV{CLASSPATH} =
    "/misc/ihome/moninger/javalibs/mysql/mysql-connector-java-3.1.13-bin.jar:".
    ".";
# connect to the database
$ENV{DBI_DSN} = "DBI:mysql:surface_sums:wolphin.fsl.noaa.gov";
$ENV{DBI_USER} = "sfc_driver5";
$ENV{DBI_PASS} = "driver5";
my ($dbh,$sth);
$dbh = DBI->connect(undef,undef,undef, {RaiseError => 0,PrintError => 1});
my $query;
$query = qq{show tables like "%q%"};
$sth = $dbh->prepare($query);
my ($qtable,$table);
$sth->execute();
$sth->bind_columns(\$qtable);
while($sth->fetch()) {
    $table = $qtable;
    $table =~ s/_q//;
    #print "$qtable, $table\n";
  WARNING: this will blow away the rh values in $qtable. We should
      really use 'on duplicate key update' to save the rh values.
    $query=<<"EOI"
replace into $qtable
(valid_day,hour,fcst_len,N_dt,sum_ob_t,sum_dt,sum2_dt,
N_dw,sum_ob_ws,sum_model_ws,sum_du,sum_dv,sum2_dw,
N_dtd,sum_ob_td,sum_dtd,sum2_dtd)
select valid_day,hour,fcst_len,N_dt,sum_ob_t,sum_dt,sum2_dt,
N_dw,sum_ob_ws,sum_model_ws,sum_du,sum_dv,sum2_dw,
N_dtd,sum_ob_td,sum_dtd,sum2_dtd
from $table
EOI
    ;
print "$query\n";
my $n_rows = $dbh->do($query);
print "$n_rows added to table $qtable\n";
	
}
