my %month_num = (Jan => 1, Feb => 2, Mar => 3, Apr => 4, May => 5, Jun => 6,
		 Jul => 7, Aug => 8, Sep => 9, Oct =>10, Nov =>11, Dec =>12);
use vars(%month_num);

sub my_timeout {
    print STDERR "timeout\n";
    die 1;
}

sub get_RR_file {
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
    my $template = sprintf("wrfnat_rr_%02d.grib1",$desired_fcst_len);
    if($data_source eq "RR1h" ||
       $data_source eq "isoRR1h" ||
       $data_source eq "RR1hB" ||  # test of corrected ij for rotLL (was off by 1)
       $data_source eq "RR1hC") {  # duplicat of RR1h, just for checking
	$anal_dir =
	    sprintf("/scratch1/portfolios/BMC/nrtrr/mhu/RR/DOMAINS/wrfrr13_cycle/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
	    if($data_source =~ /^isoRR1h/) {
		$template = sprintf("wrfprs_130_%02d.grib1",$desired_fcst_len);
	    }
    } elsif($data_source eq "RAP" ) {
	$anal_dir =
	    sprintf("$ENV{GSDPUBLIC}/data/grids/rap/hyb_A252/grib2",
		$year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "RR1h_dev3" ) {
	$anal_dir =
	    sprintf("/scratch1/portfolios/BMC/nrtrr/mhu/RR/DOMAINS/wrfrr13_cycle/%4d%2.2d%2.2d%2.2d/postprd",
		$year+1900,$month+1,$mday,$hour);

    }elsif($data_source eq "RAP_dev1" ) {
	$anal_dir =
	    sprintf("/home/rtrr/rap_dev1/%4d%2.2d%2.2d%2.2d/postprd",
		$year+1900,$month+1,$mday,$hour);
    }elsif($data_source eq "RAP_dev2" ) {
	$anal_dir =
	    sprintf("/home/rtrr/rap_dev2/%4d%2.2d%2.2d%2.2d/postprd",
		$year+1900,$month+1,$mday,$hour);
    }elsif($data_source eq "RAP_dev3" ) {
	$anal_dir =
	    sprintf("/home/rtrr/rap_dev3/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
    }elsif($data_source eq "RAP_dev_sat" ) {
	$anal_dir =
	    sprintf("/scratch2/portfolios/BMC/zrtrr/hlin/RAPdev_sat_databasedir/cycle//%4d%2.2d%2.2d%2.2d/postprd",
		$year+1900,$month+1,$mday,$hour);
    }elsif($data_source eq "RAP_dev_sat_2" ) {
	$anal_dir =
	    sprintf("/scratch2/portfolios/BMC/zrtrr/hlin/RAPdev_sat_2_databasedir/cycle//%4d%2.2d%2.2d%2.2d/postprd",
		$year+1900,$month+1,$mday,$hour);
    }elsif($data_source eq "RR1h_dev" ||
	    $data_source eq "RR1h_dev130" ||
	    $data_source eq "isoRR1h_dev") {
	$anal_dir =
	    sprintf("/whome/rtrr/rr_devel/%4d%2.2d%2.2d%2.2d/postprd",
		$year+1900,$month+1,$mday,$hour);
	    if ($data_source eq "RR1h_dev130") {
		$template = sprintf("wrfnat_130_%02d.grib1",$desired_fcst_len);
	    }
   } elsif($data_source eq "RR1h_dev2") {
	$anal_dir =
	    sprintf("/whome/rtrr/rr_devel2/%4d%2.2d%2.2d%2.2d/postprd",
		$year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "RRnc") {
	$anal_dir =
	    sprintf("/scratch1/portfolios/BMC/wrfruc/smirnova/DOMAINS/rll_cold/%4d%2.2d%2.2d%2.2d/postprd",
		$year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "STMAS_CI") {
	$anal_dir = "/scratch1/portfolios/BMC/dlaps/analysis/stmas_ci/lapsprd/fua/wrf-wsm6";
	$template =  sprintf("%02d%03d%02d00%02d00.fua",
			    $year%100,$jday,$hour,$desired_fcst_len);
    } elsif($data_source eq "STMAS_HWT") {
	$anal_dir = "/scratch1/portfolios/BMC/dlaps/analysis/stmas_hwt/lapsprd/fua/wrf-wsm6";
	$template =  sprintf("%02d%03d%02d00%02d00.fua",
			    $year%100,$jday,$hour,$desired_fcst_len);
    } elsif($data_source eq "LAPS_HWT") {
	$anal_dir = "/scratch1/portfolios/BMC/dlaps/analysis/laps_hwt/lapsprd/fua/wrf-wsm6";
	$template =  sprintf("%02d%03d%02d00%02d00.fua",
			    $year%100,$jday,$hour,$desired_fcst_len);
    } elsif($data_source eq "LAPS_CONUS") {
	$anal_dir = "/scratch1/portfolios/BMC/dlaps/analysis/laps_conus/lapsprd/fua/wrf-tom";
	$template =  sprintf("%02d%03d%02d00%02d00.fua",
			    $year%100,$jday,$hour,$desired_fcst_len);
    } elsif($data_source eq "RRncRLL") {
	$anal_dir =
	    sprintf("/lfs1/projects/wrfruc/DOMAINS/rr_rll/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "HRRR") {
	$anal_dir =
	    sprintf("/whome/rtrr/hrrr/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
	$template = sprintf("wrfnat_hrconus_%02d.grib1",$desired_fcst_len);
    } elsif($data_source eq "HRRR_dev1") {
	$anal_dir =
	    sprintf("/home/rtrr/hrrr_dev1/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
	$template = sprintf("wrfnat_hrconus_%02d.grib1",$desired_fcst_len);
	# don't need to worry about .al00 files for HRRR, because they don't exist.
    } elsif($data_source eq "HRRR_dev2") {
	$anal_dir =
	    sprintf("/home/rtrr/hrrr_dev2/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
	$template = sprintf("wrfnat_hrconus_%02d.grib1",$desired_fcst_len);
	# don't need to worry about .al00 files for HRRR, because they don't exist.
    } elsif($data_source eq "RRrapx") {
	$anal_dir = "$ENV{GSDPUBLIC}/data/grids/rr/hyb_130/grib2";
    } elsif($data_source eq "RAPv2_EMC" ) {  # xue added sep 5th 2013
	$anal_dir = "/scratch1/portfolios/BMC/public//data/grids/rapv2/hyb_130/grib2";
	$template =  sprintf("%02d%03d%02d0000%02d",
			    $year%100,$jday,$hour,$desired_fcst_len);
    } elsif($data_source eq "isoRRrapx221") {
	$anal_dir = "$ENV{GSDPUBLIC}/data/grids/rap/awip32/grib2";
    } elsif($data_source eq "RRrapx252") {
	$anal_dir = "$ENV{GSDPUBLIC}/data/grids/rr/hyb_A252/grib2";
    } elsif($data_source eq "isoRRrapx") {
	$anal_dir = "$ENV{GSDPUBLIC}/data/grids/rr/iso_130/grib2";
    } elsif($data_source =~ /^RROU/) {
	$anal_dir =
	    sprintf("RR_retro/$data_source/%4d%2.2d%2.2d%2.2d/postprd40km",
		    $year+1900,$month+1,$mday,$hour);
	$template = sprintf("wrfnat%02d",$desired_fcst_len);
    } else {
	$anal_dir =
	    sprintf("RR_retro/$data_source/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
	if($data_source =~ /^HRRR/) {
	    $template = sprintf("wrfnat_hrconus_%02d.grib1",$desired_fcst_len);
	}
    }
    if($anal_dir =~ m|/public/|) {
	$template =  sprintf("%02d%03d%02d%06d",
			    $year%100,$jday,$hour,$desired_fcst_len);
    }
    if($special_type eq "analysis") {
	$template =~ s/\.grib1$/\.al00/;
    }

    print "template for $template\n";

    $type = "A";
    if($desired_fcst_len > 0) {
	$type = "F";
    }
    $out_file = "$anal_dir/$template";
    if($DEBUG) {
	print "looking for $out_file\n";
    }
    if(-r $out_file &&
       -M $out_file > 0.0014) {	# 0.0014 days =~ 2 minutes
	if($DEBUG) {
	    #print "FOUND $out_file\n";
	}
	return ($out_file,$type,$desired_fcst_len);
    } else {
	if($DEBUG) {
	    #print "NOT FOUND $out_file\n";
	}
	return(undef,$out_file,undef);
    }
}

1;    # return something so the require is happy
