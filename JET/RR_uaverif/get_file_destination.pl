my %month_num = (Jan => 1, Feb => 2, Mar => 3, Apr => 4, May => 5, Jun => 6,
		 Jul => 7, Aug => 8, Sep => 9, Oct =>10, Nov =>11, Dec =>12);
use vars(%month_num);

sub my_timeout {
    print STDERR "timeout\n";
    die 1;
}

sub get_destination_file {
    my($run_time,$data_source,$DEBUG,$desired_fcst_len,$special_type) = @_;
    my @result = "";
    my @r;
    @result = eval <<'END';
    alarm(10);			# 10-sec time limit on getting filename
    @r = get_model_file2($run_time,$data_source,$DEBUG,$desired_fcst_len,$special_type);
    alarm(0);			# reset alarm
    @r;
END
    if($@) {			#check for an error on the eval
	print "Bad eval: $@\n";
	@result="";
    }
    #print "result is @result\n";
    return @result;
}

sub get_model_file2 {
    my($run_time,$data_source,$DEBUG,$desired_fcst_len,$special_type)=@_;
    my ($out_file,$type,$fcst_len);    
    my ($dym,$dym,$hour,$mday,$month,$year,$wday,$yday) =
	gmtime($run_time);
    my $jday=$yday+1;
    unless(defined $desired_fcst_len) {
	print "TROUBLE: must define desired_fcst_len\n";
    }


    my $anal_dir;
    my $template="";
    print "data source: $data_source";
    if($data_source eq "FV3_GFS_EMC") {
	$dest_dir = "/lfs1/BMC/amb-verif/grids/fv3gfs_emc/0p25deg/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } else {
        print "ERROR: data source not listed in this file! Exiting...\n";
        exit(1)
    }

    unless($template) {
        print "ERROR: data source destination file template not listed in this file! Exiting...\n";
        exit(2)
    }
    $out_file = "$dest_dir/$template";

    return($out_file);
}

1;    # return something so the require is happy
