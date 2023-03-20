my %month_num = (Jan => 1, Feb => 2, Mar => 3, Apr => 4, May => 5, Jun => 6,
		 Jul => 7, Aug => 8, Sep => 9, Oct =>10, Nov =>11, Dec =>12);
use vars(%month_num);

sub get_iso_file3 {
    my($run_time,$data_source,$DEBUG,$desired_fcst_len,$start)=@_;
    my ($out_file,$type,$fcst_len);    

    unless(defined $desired_fcst_len) {
	die "must have a desired forecast len!\n";
    }

    my $anal_dir;
    if($data_source eq "RR1h_prs") {
	$anal_dir = "/whome/rtrr/rr/WRFDATE/postprd/";
    } elsif($data_source eq "Op20") {
        $anal_dir = "/public/data/grids/ruc/iso_A252/grib2/";
    } elsif($data_source eq "GLMP") {
        $anal_dir = "/public/data/grids/lamp/2p5km/grib2/";
    } elsif($data_source eq "Op13") { # 13km
        $anal_dir = "/public/data/grids/ruc/iso_130/grib2/";
    } elsif($data_source eq "dev13") {  # 13 km!
        $anal_dir = "/whome/rtruc/ruc_devel/ruc_presm/";
    } elsif($data_source eq "dev1320") {  # 20 km!
        $anal_dir = "/whome/rtruc/ruc_devel/ruc_presm20/";
    } elsif($data_source eq "Bak13") {  # 13 km!
        $anal_dir = "/whome/rtruc/ruc_backup/ruc_presm/";
    } elsif($data_source eq "NoTAM13") {  # 13 km!
        $anal_dir = "/whome/rtruc/ruc_notamdar/ruc_presm/";
    } elsif($data_source eq "NAM_NEST_AK") {  
        $anal_dir = "/pan2/projects/public/data/grids/nam/aknest/grib2/";
    } elsif($data_source =~ /^NAM/) {  # get both NAM and NAMceil
        $anal_dir = "/pan2/projects/public/data/grids/nam/nh221/grib2/";
    } elsif($data_source eq "RRnc_prs") {
	$anal_dir = "/whome/wrfruc/rr_nocyc/WRFDATE/postprd/";
    } elsif($data_source eq "RAP_OPS_iso_242") {
        $anal_dir ="/public/data/grids/rap/242_alaska/grib2/";
        #$anal_dir ="/pan2/projects/public/data/grids/rap/242_alaska/grib2/";
    } elsif($data_source eq "RAP_OPS") {
        $anal_dir = "/lfs3/BMC/amb-verif/scratch/rap_iso/";
    } elsif($data_source eq "RR1h_dev_prs") {
	$anal_dir = "/whome/rtrr/rr_devel/WRFDATE/postprd/";
    } elsif($data_source eq "RR1h_dev2_prs") {
	$anal_dir = "/whome/rtrr/rr_devel2/WRFDATE/postprd/";
    } elsif($data_source eq "HRRR_AK") {
	$anal_dir = "/whome/rtrr/hrrr_ak/WRFDATE/postprd/";
    } elsif($data_source eq "HRRR") {
	$anal_dir = "/whome/rtrr/hrrr/WRFDATE/postprd/";
    } elsif($data_source eq "HRRR_WFIP2") {
	$anal_dir = "/mnt/lfs3/BMC/nrtrr/HRRR_WFIP2/run/WRFDATE/postprd/conus/";
    } elsif($data_source eq "HRRR_NREL") {
	$anal_dir = "/pan2/projects/public/data/gsd/hrrr_nrel/conus/wrfnat/";
    } elsif($data_source eq "HRRR_OPS") {
        $anal_dir =
            sprintf("/pan2/projects/public/data/grids/hrrr/conus/wrfnat/grib2/");
    } elsif($data_source eq "HRRRv2_NCO") {
        $anal_dir =
            sprintf("/pan2/projects/public/data/grids/hrrrv2/conus/wrfnat/grib2");
    } elsif($data_source eq "RAPv3_NCO") {
            $anal_dir = sprintf("/pan2/projects/public/data/grids/rapv3/full/wrfnat/grib2/");
    } elsif($data_source eq "RAPv3_EMC_130") {
            $anal_dir = sprintf("/pan2/projects/public/data/grids/rapv3/iso_130/grib2/");
    } elsif($data_source eq "RRrapx221") {
	$anal_dir = "/pan2/projects/public/data/grids/rap/awip32/grib2/";
	#$anal_dir = "/public/data/grids/rap/awip32/grib2/";
    } else {
	$anal_dir = "retro_data/${data_source}";
    }
    if ($DEBUG) {
	print "data source is $data_source. ";
	print "Looking in directory $anal_dir\n";
    }
    # the hardest part if to get the suffix
    my $suffix = ".grib";
    if($anal_dir =~ /grib2/ ||
       $anal_dir =~ m|gsd/fim/grib| ||
       $anal_dir =~ m|amb-verif/scratch| ||
       $anal_dir =~ m|rtfim/FIM/|) {
	$suffix = "";
    } elsif ($anal_dir =~ m|/rt1/rtruc/13km/run/maps_fcst|) {
	# have .grib and .grib2 in this directory
	# .grib2 is faster, so use it.
	$suffix = ".grib2";
    }

    my ($secs,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)
	= gmtime($run_time);
    my $filename;
    if($anal_dir =~ /WRFDATE/ ||
       $anal_dir =~ /retro/) {
	# replace with the date format used by WRF (FIM and RR)
	my $fim_date = sprintf("%04d%02d%02d%02d",
			       $year+1900,$mon+1,$mday,$hour);
	if($anal_dir =~ s/WRFDATE/$fim_date/) {
	    my $base_file = sprintf("WRFNAT%02d.tm00",$desired_fcst_len);
	} else {
	    $anal_dir .= "/$fim_date/postprd/";
	}
#	if($data_source =~ /prs/) {
	if($data_source =~ /prs/ && $data_source !~ /^RR/) {
	    if($desired_fcst_len == 0) {
		$base_file = sprintf("wrfprs_rr_%02d.al00.grb2",$desired_fcst_len);
	    } else {
		$base_file = sprintf("wrfprs_rr_%02d.grib2",$desired_fcst_len);
	    }
	} elsif($data_source =~ /^HRRR/ && $data_source !~ /WFIP2/) {
	    $base_file = sprintf("wrfprs_hrconus_%02d.grib2",$desired_fcst_len);
            if($data_source eq "HRRR_AK"){
              $base_file = sprintf("wrfprs_hralaska_%02d.grib2",$desired_fcst_len); 
            }
            

	} elsif($data_source eq "HRRR_WFIP2") {
	    $base_file = sprintf("wrfnat_conus_%02d00.grib2",$desired_fcst_len);


#	} elsif($data_source =~ /^RRret/) {
	} elsif($data_source =~ /^RR/) {
	    if($desired_fcst_len == 0) {
#		$base_file = sprintf("wrfprs_rr_%02d.al00",$desired_fcst_len);
		$base_file = sprintf("wrfprs_rr_%02d.al00.grb2",$desired_fcst_len);
	    } else {
#		$base_file = sprintf("wrfprs_rr_%02d.grib1",$desired_fcst_len);
		$base_file = sprintf("wrfprs_rr_%02d.grib2",$desired_fcst_len);
	    }
	}	    
	$filename = "${anal_dir}$base_file";
    } else {
	# RUC-style filename


	$filename = sprintf("${anal_dir}%02d%03d%02d000%03d$suffix",
			       $year%100,$yday+1,$hour,
			       $desired_fcst_len);

	if($data_source eq "HRRRv2_NCO") {
            $anal_dir = sprintf("/pan2/projects/public/data/grids/hrrrv2/conus/wrfnat/grib2/");
            $base_file = sprintf("%02d%03d%02d%06d",
				$year%100,$yday+1,$hour,$desired_fcst_len);
        	$filename = "${anal_dir}$base_file";
	}
	if($data_source eq "HRRR_NREL") {
            $anal_dir = sprintf("/pan2/projects/public/data/gsd/hrrr_nrel/conus/wrfnat/");
            $base_file = sprintf("%02d%03d%02d%04d%02d",
				$year%100,$yday+1,$hour,$desired_fcst_len,0);
        	$filename = "${anal_dir}$base_file";
	}


	if($data_source eq "RAPv3_NCO") {
            $anal_dir = sprintf("/pan2/projects/public/data/grids/rapv3/full/wrfnat/grib2/");
            $base_file = sprintf("%02d%03d%02d%06d",
				$year%100,$yday+1,$hour,$desired_fcst_len);
        	$filename = "${anal_dir}$base_file";
	}


	if($data_source eq "RAPv3_EMC_130") {
            $anal_dir = sprintf("/pan2/projects/public/data/grids/rapv3/iso_130/grib2/");
            $base_file = sprintf("%02d%03d%02d%06d",
				$year%100,$yday+1,$hour,$desired_fcst_len);
        	$filename = "${anal_dir}$base_file";
	}


    }
    if($DEBUG) {
	print "filename is $filename\n";
    }
    unless(-r $filename) {
	# file not found. see if $data_source was the entire file name
	if(-r $data_source) {
	    $filename = $data_source;
	} else {
	    $filename = "";
	}
    }
	
    return ($filename,0,$desired_fcst_len);
}

1;    # return something so the require is happy
