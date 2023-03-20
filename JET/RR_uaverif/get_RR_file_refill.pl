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
    my $template="";
    print "data source: $data_source";
    if($data_source eq "RAP20") {
	$anal_dir = "/public/data/grids/rap/hyb_A252/grib2";
	#$anal_dir = "/pan2/projects/public/data/grids/rap/hyb_A252/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RAP_OPS_130") {
	$anal_dir = "/pan2/projects/public/data/grids/rap/hyb_130/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RAP_OPS_iso") {
	$anal_dir = "/lfs3/BMC/amb-verif/scratch/rap_iso";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RAPv3_EMC_130") {
	$anal_dir = "/pan2/projects/public/data/grids/rapv3/hyb_130/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
   } elsif($data_source eq "RAP_OPS_iso_242") {
        $anal_dir =
            sprintf("/public/data/grids/rap/242_alaska/grib2/",
		    $year+1900,$month+1,$mday,$hour);
#   } elsif($data_source eq "RAP_NCOpara_iso_242") {
#        $anal_dir =
#            sprintf("/public/data/grids/rapv2/242_alaska/grib2/",
#		    $year+1900,$month+1,$mday,$hour);
#    } elsif($data_source eq "RAPv3_EMC") {
   } elsif($data_source eq "RAPv3_NCO") { 
	$anal_dir =
	    sprintf("/pan2/projects/public/data/grids/rapv3/full/wrfnat/grib2");

   } elsif($data_source eq "RAP") {
       $anal_dir =
	    sprintf("/whome/rtrr/rr/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
       # change to grib2 for full RAP domain
       $template = sprintf("wrfnat_rr_%02d.grib2",$desired_fcst_len);
       if($special_type eq "analysis") {
	   $template =~ s/\.grib2$/\.al00.grb2/;
	}
    } elsif($data_source eq "RAP_NCO_noIVEA") {
        $anal_dir =
            sprintf("/lfs4/BMC/rtwbl/mhu/wcoss/emc/ncorap/%4d%2.2d%2.2d%2.2d/postprd",
                    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("rap.t%02dz.wrfnatf%02d.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "RAP_NCO_noIVEA_iso") {
        $anal_dir =
            sprintf("/lfs4/BMC/rtwbl/mhu/wcoss/emc/ncorap/%4d%2.2d%2.2d%2.2d/postprd",
                    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("rap.t%02dz.wrfprsf%02d.grib2",$hour,$desired_fcst_len);

   } elsif($data_source =~ /^RAP/ ||
	   $data_source eq "RR1h" ||
	   $data_source eq "RAP_iso_130" ||
	   $data_source eq "RR1hB" ||  # test of corrected ij for rotLL (was off by 1)
	   $data_source eq "RR1hC") {  # duplicat of RR1h, just for checking
       $anal_dir =
	    sprintf("/whome/rtrr/rr/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);

    } elsif($data_source eq "RR1h_dev" ||
	    $data_source eq "RR1h_dev130" ||
	    $data_source eq "isoRR1h_dev") {
	$anal_dir =
	    sprintf("/whome/rtrr/rr_devel/%4d%2.2d%2.2d%2.2d/postprd",
		$year+1900,$month+1,$mday,$hour);

   } elsif($data_source eq "RR1h_dev2") {
	$anal_dir =
	    sprintf("/whome/rtrr/rr_devel2/%4d%2.2d%2.2d%2.2d/postprd",
		$year+1900,$month+1,$mday,$hour);

    } elsif($data_source eq "RRnc") {
	$anal_dir =
	    sprintf("/whome/wrfruc/rr_nocyc/%4d%2.2d%2.2d%2.2d/postprd",
		$year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "RRncRLL") {
	$anal_dir =
	    sprintf("/lfs1/BMC/wrfruc/DOMAINS/rr_rll/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "RUA_iso") {
        $anal_dir = 
	    sprintf("/lfs3/BMC/nrtrr/RUA/run/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "RUA_AK_iso") {
        $anal_dir = 
	    sprintf("/lfs3/BMC/nrtrr/RUA_AK/run/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "HRRR") {
	$anal_dir =
	    sprintf("/whome/rtrr/hrrr/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "HRRR_dev3") {
	$anal_dir =
	    sprintf("/lfs3/BMC/wrfruc/HRRR_dev3/run/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("wrfnat_hrconus_%02d.grib2",$desired_fcst_len);
    } elsif($data_source eq "HRRRE_mem1") {
	$anal_dir =
	    sprintf("/lfs1/BMC/amb-verif/ua_temp_data/HRRRrun/%4d%2.2d%2.2d%2.2d/postprd_mem0001",
		    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("wrfnat_mem0001_%02d.grib2",$desired_fcst_len);
    } elsif($data_source eq "HRRRE_mem2") {
	$anal_dir =
	    sprintf("/lfs1/BMC/amb-verif/ua_temp_data/HRRRrun/%4d%2.2d%2.2d%2.2d/postprd_mem0002",
		    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("wrfnat_mem0002_%02d.grib2",$desired_fcst_len);
    } elsif($data_source eq "HRRRE_mem3") {
	$anal_dir =
	    sprintf("/lfs1/BMC/amb-verif/ua_temp_data/HRRRrun/%4d%2.2d%2.2d%2.2d/postprd_mem0003",
		    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("wrfnat_mem0003_%02d.grib2",$desired_fcst_len);
    } elsif($data_source eq "HRRR_AK" || $data_source eq "HRRR_AK_iso") {
	$anal_dir =
	    sprintf("/whome/rtrr/hrrr_ak/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "HRRR_HI" || $data_source eq "HRRR_HI_iso") {
	$anal_dir =
	    sprintf("/whome/rtrr/hrrr_hi/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "NAM_NEST_AK") {
	$anal_dir =
	    sprintf("/pan2/projects/public/data/grids/nam/aknest/grib2");
    } elsif($data_source eq "NAM_NEST_HI") {
	$anal_dir =
	    sprintf("/pan2/projects/public/data/grids/nam/hawaiinest/grib2");
    } elsif($data_source eq "HRRRv2_NCO") {
	$anal_dir =
	    sprintf("/pan2/projects/public/data/grids/hrrrv2/conus/wrfnat/grib2");
    } elsif($data_source eq "HRRR_WFIP2") {
        $anal_dir =
            sprintf("/mnt/lfs3/BMC/nrtrr/HRRR_WFIP2/run/%4d%2.2d%2.2d%2.2d/postprd/conus",
                    $year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "HRRR_NREL") {
        $anal_dir =
	    sprintf("/pan2/projects/public/data/gsd/hrrr_nrel/conus/wrfnat");
    } elsif($data_source eq "HRRR_OPS") {
#	$anal_dir =
#	    sprintf("/public/gsd/hrrr_ncep/conus/wrfnat/");

	$anal_dir =
	    sprintf("/pan2/projects/public/data/grids/hrrr/conus/wrfnat/grib2/");
    } elsif($data_source eq "HRRR_iso") {
	$anal_dir =
	    sprintf("/whome/rtrr/hrrr/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);

    } elsif($data_source eq "HRRR_dev") {
	$anal_dir =
	    sprintf("/whome/rtrr/hrrr_devel/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
    #} elsif($data_source eq "RRrapx") {
	#$anal_dir = "/public/data/grids/rr/hyb_130/grib";
    } elsif($data_source eq "isoRRrapx221") {
	$anal_dir = "/pan2/projects/public/data/grids/rap/awip32/grib2";
    } elsif($data_source eq "RRrapx252") {
	$anal_dir = "/pan2/projects/public/data/grids/rap/hyb_A252/grib2";
    } elsif($data_source eq "isoRRrapx") {
	$anal_dir = "/pan2/projects/public/data/grids/rap/iso_130/grib2";
    } elsif($data_source =~ /^RROU/) {
	$anal_dir =
	    sprintf("RR_retro/$data_source/%4d%2.2d%2.2d%2.2d/postprd40km",
		    $year+1900,$month+1,$mday,$hour);
    } else {
	$anal_dir =
	    sprintf("RR_retro/$data_source/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
    }

    unless($template) {
	$template = sprintf("wrfnat_rr_%02d.grib2",$desired_fcst_len);
	# RR file names
	if($data_source =~ /^RRnc/) {
	    $template = sprintf("wrfnat_rr_%02d.tm00",$desired_fcst_len);
	    # no .al00 files for RRnc
	} elsif($data_source eq "NAM_NEST_AK") {
            $template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
	} elsif($data_source eq "HRRRv2_NCO") {
            $template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
	} elsif($data_source eq "RAPv3_NCO") {
            $template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
        } elsif($data_source eq "RUA_iso") {
            $template = sprintf("wrfprs_hrconus_%02d.grib2",$desired_fcst_len);
        } elsif($data_source eq "RUA_AK_iso") {
            $template = sprintf("wrfprs_hrconus_%02d.grib2",$desired_fcst_len);
	} elsif($data_source =~ /HRRRret/) {
	    $template = sprintf("wrfnat_hrconus_%02d.grib2",$desired_fcst_len);
	} elsif($data_source =~ /RRret/) {
	    $template = sprintf("wrfnat_rr_%02d.grib2",$desired_fcst_len);
	} elsif($data_source eq "HRRR") {
	    $template = sprintf("wrfnat_hrconus_%02d.grib2",$desired_fcst_len);
	} elsif($data_source eq "HRRR_AK") {
	    $template = sprintf("wrfnat_hralaska_%02d.grib2",$desired_fcst_len);
	} elsif($data_source eq "HRRR_AK_iso") {
	    $template = sprintf("wrfprs_hralaska_%02d.grib2",$desired_fcst_len);
	} elsif($data_source eq "HRRR_HI") {
	    $template = sprintf("wrfnat_hrhawaii_%02d.grib2",$desired_fcst_len);
	} elsif($data_source eq "HRRR_HI_iso") {
	    $template = sprintf("wrfprs_hrhawaii_%02d.grib2",$desired_fcst_len);
        } elsif($data_source eq "HRRR_WFIP2") {
            $template = sprintf("wrfnat_conus_%02d00.grib2",$desired_fcst_len);
	} elsif($data_source eq "HRRR_OPS") {
	    $template = sprintf("%02d%03d%02d00%04d",
				$year%100,$yday+1,$hour,$desired_fcst_len);
	} elsif($data_source eq "HRRR_NREL") {
	    $template = sprintf("%02d%03d%02d%04d00",
				$year%100,$yday+1,$hour,$desired_fcst_len);
	} elsif($data_source eq "HRRR_iso") {
	    $template = sprintf("wrfprs_hrconus_%02d.grib2",$desired_fcst_len);
	    # dont need to worry about .al00 files for HRRR, because they don't exist.
	} elsif($data_source =~ /^isoRR1h/) {
	    $template = sprintf("wrfprs_130_%02d.grib2",$desired_fcst_len);
	} elsif($data_source eq "RAP_iso_130") {
	    $template = sprintf("wrfprs_130_%02d.grib2",$desired_fcst_len);
	} elsif ($data_source =~ /130/) {
	    $template = sprintf("wrfnat_130_%02d.grib2",$desired_fcst_len);
	} elsif($data_source =~ /RRrapx/ || $data_source =~ /OPS/) {
	    $template = sprintf("%02d%03d%02d%06d",
				$year%100,$yday+1,$hour,$desired_fcst_len);
	} elsif($data_source =~ /^RROU/) {
	    $template = sprintf("wrfnat%02d",$desired_fcst_len);
	}
	if($special_type eq "analysis") {
	    $template =~ s/\.grib1$/\.al00/;
	}
    }
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
