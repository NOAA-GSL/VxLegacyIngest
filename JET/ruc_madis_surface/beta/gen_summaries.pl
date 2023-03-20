#!/usr/bin/perl
#
use strict;
use Time::Local;
use DBI;
require "./set_connection.pl";
$ENV{DBI_DSN} = "DBI:mysql:surface_sums:wolphin.fsl.noaa.gov";
# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 0, PrintError => 1});
my $query;
foreach my $data_source (qw(HRRR)) {
    #my @fcst_lens = (1,3,6,9,12);
   #foreach my $fcst_len (@fcst_lens) {
	foreach my $region (qw[ALL_RR1 ALL_RUC E_RUC W_RUC ALL_HRRR E_HRRR W_HRRR AK HWT STMAS_CI] ) {
	    my $table = "${data_source}_metar_q_${region}";
	    #my $old_table = "${data_source}_${fcst_len}_metar_${region}";
	    my $old_table = "xxx";
	    #$query = qq[drop table if exists $table];
	    #x$dbh->do($query);
	    $query = qq[create table if not exists $table like template_q];
	    #$query = qq[drop table if exists $table];
	    print "$query\n";
	    $dbh->do($query);
	    $query=<<"EOI"
replace into $table
(valid_day,hour,fcst_len,N_dt,sum_ob_t,sum_dt,sum2_dt,
N_dw,sum_ob_ws,sum_model_ws,sum_du,sum_dv,sum2_dw,
N_dtd,sum_ob_td,sum_dtd,sum2_dtd)
select valid_day,hour,fcst_len,N_dt,sum_ob_t,sum_dt,sum2_dt,
N_dw,sum_ob_ws,sum_model_ws,sum_du,sum_dv,sum2_dw,
N_dtd,sum_ob_td,sum_dtd,sum2_dtd
from $old_table
EOI
    ;
#print "$query\n";
#my $n_rows = $dbh->do($query);
#print "$n_rows added to table $table\n";
		
	}
    }
#}
