sub move_summaries {
    my($model,$valid_time) = @_;
    use Time::Local;
    use DBI;
    #connect
    require "./set_connection3.pl";
    # re-set the db to ceiling_sums
    $ENV{DBI_DSN} = "DBI:mysql:vgtyp_sums:wolphin";
    my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
    my $valid_string = gmtime($valid_time);
    print "FILLING VGTYP SUMMARY TABLES FOR $model valid at $valid_string\n\n";

    my $table = "${model}";
    
    print "table=$table \n";

    $query = qq(show tables like "$table");
    my $result = $dbh->selectrow_array($query);
    unless($result) {
       $query = "create table $table like template";
       $dbh->do($query);
    }
    my $old_table = "surface_sums.${model}_vgtyp";
    $query = qq[
replace into $table (valid_day,hour,fcst_len,vgtyp,N_dt,sum_ob_t,sum_dt,sum2_dt,N_dw,sum_ob_ws,sum_model_ws,sum_du,sum_dv,sum2_dw,N_dtd,sum_ob_td,sum_dtd,sum2_dtd,N_drh,sum_ob_rh,sum_drh,sum2_drh,sum_adt,sum_adtd)
select ot.valid_day as valid_day,
 ot.hour as hour,
 ot.fcst_len as fcst_len,
 ot.vgtyp as vgtyp,
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
 ot.N_dtd as N_dtd,
 ot.sum_ob_td as sum_ob_td,
 ot.sum_dtd as sum_dtd,
 ot.sum2_dtd as sum2_dtd,
 ot.N_drh as N_drh,
 ot.sum_ob_rh as sum_ob_rh,
 ot.sum_drh as sum_drh,
 ot.sum2_drh as sum2_drh,
 ot.sum_adt as sum_adt,
 ot.sum_adtd as sum_adtd
from
$old_table as ot
where 1 = 1
and ot.valid_day = $valid_time
]; 
    print "query=$query\n";
    $dbh->do($query);


$dbh->disconnect();
}
1;
