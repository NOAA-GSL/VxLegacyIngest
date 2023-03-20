sub update_bad_tails {
    my($dbh) = @_;
    my (%N_T,%bias_T,%std_T,%bias_S,%std_S,%bias_DIR,%std_DIR,
    %std_W,%rms_W,%bias_RH,%std_RH,%entries,%model,
    %mdcrs_id,%fsl_id);
    my($tailnum,$N_T,$avg_T,$bias_T,$std_T,
       $N_S,$avg_S,$bias_S,$std_S,$bias_DIR,$std_DIR,
       $std_W,$rms_W,$N_RH,$avg_RH,$bias_RH,$std_RH,$model,
       $mdcrs_id,$fsl_id);
    my %error_list;
    my %line;
    my @vars = qw(bias_T std_T bias_S std_S bias_DIR std_DIR std_W rms_W bias_RH std_RH);

    # NEED TO CLEAR ALL ENTRIES FIRST!!!
    $query = "lock tables tail write, limits read, 7day read"; 
    $rows = $dbh->do($query);
    print "$query ... $rows affected\n";
    $query = "update tail set current_bad_t =0,current_bad_W = 0,current_bad_RH = 0";
    $rows = $dbh->do($query);
    print "$query ... $rows affected\n";

    # get errors from GSD's AMDAR-RR database
    # get limits from the database
    $query = qq|
    select bias_T_limit,std_T_limit,bias_S_limit,std_S_limit,
    bias_DIR_limit,std_DIR_limit,S_for_DIR_limit,std_W_limit,rms_W_limit,
    bias_RH_limit,std_RH_limit
    from limits|;
    my $sth_lim = $dbh->prepare($query);
    $sth_lim->execute();
    my($bias_T_limit,$std_T_limit,$bias_S_limit,$std_S_limit,
       $bias_DIR_limit,$std_DIR_limit,$S_for_DIR_limit,$std_W_limit,$rms_W_limit,
       $bias_RH_limit,$std_RH_limit) =
	   $sth_lim->fetchrow_array();
    $sth_lim->finish();

    my $stats_table = "7day";
    my %limit= (
	bias_T => $bias_T_limit,
	std_T => $std_T_limit,
	bias_S => $bias_S_limit,
	std_S => $std_S_limit,
	bias_DIR => $bias_DIR_limit,
	std_DIR => $std_DIR_limit,
	std_W => $std_W_limit,
	rms_W => $rms_W_limit,
	bias_RH => $bias_RH_limit,
	std_RH => $std_RH_limit
	);
    foreach my $var (@vars) {
	my $test_string = "and abs($var) > $limit{$var}";
	$query =<<"EOQ";
	select tailnum, tail.xid,  N_T, bias_T, std_T, 
	bias_S, std_S, bias_DIR, std_DIR, std_W, rms_W,
	bias_RH, std_RH, tail.model,
	tail.mdcrs_id
	    from $stats_table, tail where
	    $stats_table.xid = tail.xid
	    $test_string
EOQ
;
	#print $query;

	$sth = $dbh->prepare($query);
	$sth->execute();
	$sth->bind_columns(\$tailnum,\$fsl_id,
			   \$N_T,\$bias_T,\$std_T,
			   \$bias_S,\$std_S,\$bias_DIR,\$std_DIR,
			   \$std_W,\$rms_W,\$bias_RH,\$std_RH,
			   \$model,\$mdcrs_id);
	while($sth->fetch()) {
	    $entries{$tailnum} = 1;
	    $error_list{$tailnum} .= " $var";
	    $N_T{$tailnum} = $N_T;
	    $bias_T{$tailnum} = $bias_T;
	    $std_T{$tailnum} = $std_T;
	    $bias_S{$tailnum} = $bias_S;
	    $std_S{$tailnum} = $std_S;
	    $bias_DIR{$tailnum} = $bias_DIR;
	    $std_DIR{$tailnum} = $std_DIR;
	    $std_W{$tailnum} = $std_W;
	    $rms_W{$tailnum} = $rms_W;
	    $bias_RH{$tailnum} = $bias_RH;
	    $std_RH{$tailnum} = $std_RH;
	    $model{$tailnum} = $model;
	    $mdcrs_id{$tailnum} = $mdcrs_id;
	    $fsl_id{$tailnum} = $fsl_id;
	}
    }
    $sth->finish();

    
    foreach my $tail (sort keys %entries) {
	if($error_list{$tail} =~ /_T/) {
	    $query = "update tail set current_bad_T = 1 where tailnum = '$tail'";
	    my $rows = $dbh->do($query);
	    print "$query ... $rows rows updated\n";
	}
	if($error_list{$tail} =~ /_(S|D|W)/) {
	    $query = "update tail set current_bad_W = 1 where tailnum = '$tail'";
	    my $rows = $dbh->do($query);
	    print "$query ... $rows rows updated\n";
	}
	if($error_list{$tail} =~ /_R/) {
	    $query = "update tail set current_bad_RH = 1 where tailnum = '$tail'";
	    my $rows = $dbh->do($query);
	    print "$query ... $rows rows updated\n";
	}
    }
    $query = "unlock tables";
    $rows = $dbh->do($query);
    print "$query... $rows rows affected\n";
}
1;
    


