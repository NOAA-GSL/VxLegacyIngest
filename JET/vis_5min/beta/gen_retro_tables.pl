sub gen_retro_tables {
    my ($exp_name,$dbh,$DEBUG) = @_;
    unless($exp_name) {
	return;
    }
    $dbh->do("use ceiling2");
    my $query = qq(show tables like "$exp_name");
    my $result = $dbh->selectrow_array($query);
    print "query is $query\nresult of show tables is $result\n";
    if($result) {
	return;
    }

    $query = "create table ceiling2.$exp_name like template";
    if($DEBUG) {print "query is $query\n";}
    ;
    unless($dbh->do($query)) {
	# the create command failed. The table must be already there
	if($DEBUG) {print "query failed. Table already there\n"}
	return;
    }
    # now create the summary tables in ceiling_sums
    $dbh->do("use ceiling_sums2");

    my $model = $exp_name;
    my $retro_temp = "";
    if ($model =~ /AK/) {
       $retro_temp = "AK_retro";
    } elsif ($model =~ /HRRR/) {
       $retro_temp = "HRRR_retro";
    } else {
       $retro_temp = "RAP_retro";
    }
    # find our necessary regions
    $query =<<"EOI"
select regions_name from ceiling2.regions_per_model where 1=1
and model = "$retro_temp"
EOI
;
    print "$query;\n";
    my @result = $dbh->selectrow_array($query);
    my @regions = split(/,/,$result[0]);
    print "regions: @regions\n";
    foreach my $region (@regions)  {
	my $table = "${model}_$region";
    
	$query = qq[create table $table like template]; 
        print "$query;\n";
        print Q "$query\n;\n\n";
        $dbh->do($query);
    }
}
1;

