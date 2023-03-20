my %month_num = (Jan => 1, Feb => 2, Mar => 3, Apr => 4, May => 5, Jun => 6,
		 Jul => 7, Aug => 8, Sep => 9, Oct =>10, Nov =>11, Dec =>12);
use vars(%month_num);

sub my_timeout {
    print STDERR "timeout\n";
    die 1;
}

sub get_RR_prs_file {
    my($run_time,$data_source,$DEBUG,$desired_fcst_len,$start) = @_;
    my @result = "";
    my @r;
    @result = eval <<'END';
    alarm(10);			# 10-sec time limit on getting filename
    @r = get_model_file2($run_time,$data_source,$DEBUG,$desired_fcst_len,$start);
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
    my($run_time,$data_source,$DEBUG,$desired_fcst_len,$start)=@_;
    my ($out_file,$type,$fcst_len);    
    my ($dym,$dym,$hour,$mday,$month,$year,$wday,$yday) =
	gmtime($run_time);
    my $jday=$yday+1;
    if($DEBUG) {
	print "model run: year,month,jday,hour = $year, $month, $jday, $hour\n";
    }
    unless(defined $desired_fcst_len) {
	print "TROUBLE: must define desired_fcst_len\n";
    }

    my $template = sprintf("wrfprs_rr_%02d.grib1",$desired_fcst_len);
    my $anal_dir;
    if($data_source eq "RAP_iso") {
	$anal_dir =
	    sprintf("/whome/rtrr/rr/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
	$template = sprintf("wrfprs_rr_%02d.grib2",$desired_fcst_len);
    } elsif($data_source eq "HRRR_iso") {
	$anal_dir =
	    sprintf("/whome/rtrr/hrrr/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
	$template = sprintf("wrfprs_hrconus_%02d.grib2",$desired_fcst_len);
    } elsif($data_source eq "RAP_OPS_iso_130") {
	$anal_dir = "/pan2/projects/public/data/grids/rap/iso_130/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RAPv3_NCO_iso_130") {
	$anal_dir = "/pan2/projects/public/data/grids/rapv3/iso_130/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "HRRRv2_NCO_iso") {
	$anal_dir = "/pan2/projects/public/data/grids/hrrrv2/conus/wrfprs/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "NAM_OPS_iso_221") {
	$anal_dir = "/public/data/grids/nam/nh221/grib2";
	#$anal_dir = "/pan2/projects/public/data/grids/nam/nh221/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RAP_iso_130") {
	$anal_dir =
	    sprintf("/whome/rtrr/rr/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
	$template = sprintf("wrfprs_130_%02d.grib2",$desired_fcst_len);
    } elsif($data_source eq "RR1h_dev") {
	$anal_dir =
	    sprintf("/whome/wrfruc/rr_devel/%4d%2.2d%2.2d%2.2d/postprd",
		$year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "RRnc") {
	$anal_dir =
	    sprintf("/whome/wrfruc/rr_nocyc/%4d%2.2d%2.2d%2.2d/postprd",
		$year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "GFS_OPS_iso") {
	#$anal_dir = "/pan2/projects/public/data/grids/gfs/0p5deg/netcdf";
	$anal_dir = "/public/data/grids/gfs/0p5deg/netcdf";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "FIM_iso_4") {
	$anal_dir = "/public/gsd/fim/netcdf";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } else {
	$anal_dir =
	    sprintf("RR_retro/$data_source/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
    }
    
    $type = "A";
    if($desired_fcst_len > 0) {
	$type = "F";
    }
    $out_file = "$anal_dir/$template";
    if ($DEBUG) {
	print "data source is $data_source.  looking ";
	print "for $out_file\n";
    }
    if(-r $out_file) {
	return ($out_file,$type,$desired_fcst_len);
    } else {
	return(undef,$out_file,undef);
    }
}

1;    # return something so the require is happy
