sub move_summaries {
    my($model,$valid_time) = @_;
    use Time::Local;
    use DBI;
    #connect
    require "./set_connection3.pl";
    # re-set the db to ceiling_sums
    $ENV{DBI_DSN} = "DBI:mysql:surface_sums2:wolphin";
    my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
    my $valid_string = gmtime($valid_time);
    print "FILLING SUMMARY TABLES FOR $model valid at $valid_time, $valid_string\n\n";

$dbh->do("use madis3");
# find our necessary regions
$query =<<"EOI"
select regions_name from madis3.regions_per_model where 1=1
and model = "$model"
EOI
;
my @result = $dbh->selectrow_array($query);
my @regions = split(/,/,$result[0]);
# find our necessary fcst lengths
$query =<<"EOI"
select fcst_lens from madis3.fcst_lens_per_model where 1=1
and model = "$model"
EOI
;
my @result = $dbh->selectrow_array($query);
my @fcst_lens = split(/,/,$result[0]);
$dbh->do("use surface_sums2");

#print "regions: @regions\n";
#print "fcst_lens: @fcst_lens\n";

my $do_qc_table;

foreach my $region (@regions)  {
    if($region eq "HI") {
       next;
    }
    $do_qc_table = 0;
    my $table = "${model}_metar_v2_$region";
    my $qc_table = "${model}_metar_v3u_$region";
    
    #print "table = $table \n";

    $query = qq(show tables like "$table");
    my $result = $dbh->selectrow_array($query);
    unless($result) {
       $query = "create table $table like template";
       $dbh->do($query);
    }
    # check to see if qc table exists
    $dbh->do("use surface_sums");
    $query = qq(show tables like "$qc_table");
    #print "qc table query = $query\n";
    my $result = $dbh->selectrow_array($query);
    if ($result ne "") {
       $do_qc_table = 1;
       $dbh->do("use surface_sums2");
       $query = qq(show tables like "$qc_table");
       my $result_new = $dbh->selectrow_array($query);
       unless($result_new) {
          $query = "create table $qc_table like template";
          $dbh->do($query);
       }
    }

    $dbh->do("use surface_sums2");

    my $use_fcst_len = 0;

    $dbh->do("use surface_sums");
    my $old_table1 = "${model}_metar_v2_$region";
    my $old_table2 = "${model}_metar_q_$region";
    my $old_table3 = "${model}_1_metar_q_$region";
    my $old_table4 = "${model}_1_metar_$region";
    my $old_table;

    $query = qq(show tables like "$old_table1");
    my $result1 = $dbh->selectrow_array($query);
    $query = qq(show tables like "$old_table2");
    my $result2 = $dbh->selectrow_array($query);
    $query = qq(show tables like "$old_table3");
    my $result3 = $dbh->selectrow_array($query);
    $query = qq(show tables like "$old_table4");
    my $result4 = $dbh->selectrow_array($query);
    $query = qq(show tables like "$qc_table");
    my $result_qc = $dbh->selectrow_array($query);


    $dbh->do("use surface_sums");
    my $old_table1 = "${model}_metar_v2_$region";
    my $old_table2 = "${model}_metar_q_$region";
    my $old_table3 = "${model}_${fcst_len}_metar_q_$region";
    my $old_table4 = "${model}_${fcst_len}_metar_$region";
    my $old_table;

    $query = qq(show tables like "$old_table1");
    my $result1 = $dbh->selectrow_array($query);
    $query = qq(show tables like "$old_table2");
    my $result2 = $dbh->selectrow_array($query);
    $query = qq(show tables like "$old_table3");
    my $result3 = $dbh->selectrow_array($query);
    $query = qq(show tables like "$old_table4");
    my $result4 = $dbh->selectrow_array($query);
    $query = qq(show tables like "$qc_table");
    my $result_qc = $dbh->selectrow_array($query);
    
    #print "$query\n";
    #print "$result_qc\n";

    if ($result1 ne "") {
       $old_table = $old_table1;
    } elsif ($result2 ne "") {
       $old_table = $old_table2;
    } elsif ($result3 ne "") {
       $old_table = $old_table3;
       $use_fcst_len = 1;
    } elsif ($result4 ne "") {
       $old_table = $old_table4;
       $use_fcst_len = 1;
    } else {
       print "Can't find the old table to use for this model. Exiting";
       exit(3);
    }
   # print "old_table = $old_table \n";
    
    my $field_list = "valid_day,hour,fcst_len,N_dt,sum_ob_t,sum_dt,sum2_dt,N_dw,sum_ob_ws,sum_model_ws,sum_du,sum_dv,sum2_dw,N_dtd,sum_ob_td,sum_dtd,sum2_dtd";
    my $has_rh = 0;
    my $has_mae = 0;
    $query = "describe $old_table";
    $sth = $dbh->prepare($query);
    $sth->execute();
    while(my $ref = $sth->fetchrow_hashref()) {
        if($ref->{Field} eq "sum_ob_rh") {
            $has_rh=1;
            $field_list .= ",N_drh,sum_ob_rh,sum_drh,sum2_drh";
            #break;
        }
        if($ref->{Field} eq "sum_adt") {
            $has_mae=1;
            $field_list .= ",sum_adt,sum_adtd";
            #break;
        }
    }
    $dbh->do("use surface_sums2");

    if($use_fcst_len == 1) {
      foreach my $fcst_len (@fcst_lens) {
        if($result3 ne "") {
          $old_table = "${model}_${fcst_len}_metar_q_$region";
        } elsif ($result4 ne "") {
          $old_table = "${model}_${fcst_len}_metar_$region";
        } else {
          print "Can't find the old table to use for this model. Exiting";
          exit(4);
        }
        $query =<<"EOI";
replace into $table
($field_list)
select ot.valid_day as valid_day,
 ot.hour as hour,
 ot.fcst_len as fcst_len,
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
 ot.sum2_dtd as sum2_dtd
EOI
    if ($has_rh) {
       $query .=<<"EOI"
 ,ot.N_drh as N_drh,
 ot.sum_ob_rh as sum_ob_rh,
 ot.sum_drh as sum_drh,
 ot.sum2_drh as sum2_drh
EOI
}
    if ($has_mae) {
       $query .=<<"EOI"
 ,ot.sum_adt as sum_adt,
 ot.sum_adtd as sum_adtd
EOI
}
    $query .=<<"EOI"
from
surface_sums.$old_table as ot
where 1 = 1
and ot.valid_day = $valid_time
and ot.fcst_len = $fcst_len
EOI
;
   # print "query=$query\n";
        $dbh->do($query);
      }

    } else {

      $query =<<"EOI";
replace into $table
($field_list)
select ot.valid_day as valid_day,
 ot.hour as hour,
 ot.fcst_len as fcst_len,
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
 ot.sum2_dtd as sum2_dtd
EOI
    if ($has_rh) {
       $query .=<<"EOI"
 ,ot.N_drh as N_drh,
 ot.sum_ob_rh as sum_ob_rh,
 ot.sum_drh as sum_drh,
 ot.sum2_drh as sum2_drh
EOI
}
    if ($has_mae) {
       $query .=<<"EOI"
 ,ot.sum_adt as sum_adt,
 ot.sum_adtd as sum_adtd
EOI
}
    $query .=<<"EOI"
from
surface_sums.$old_table as ot
where 1 = 1
and ot.valid_day = $valid_time
EOI
;
    #print "query=$query\n";
      $dbh->do($query);

      if ($do_qc_table = 1 && $result_qc ne "") {
        $query = qq[
replace into $qc_table (valid_day,hour,fcst_len,N_dt,sum_ob_t,sum_dt,sum2_dt,N_dw,sum_ob_ws,sum_model_ws,sum_du,sum_dv,sum2_dw,N_dtd,sum_ob_td,sum_dtd,sum2_dtd,N_drh,sum_ob_rh,sum_drh,sum2_drh,sum_adt,sum_adtd)
select ot.valid_day as valid_day,
 ot.hour as hour,
 ot.fcst_len as fcst_len,
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
surface_sums.$qc_table as ot
where 1 = 1
and ot.valid_day = $valid_time
];
       #print "qc_query=$query\n";
        $dbh->do($query);
    }
  
}}

$dbh->disconnect();
}
1;
