my %month_num = (Jan => 1, Feb => 2, Mar => 3, Apr => 4, May => 5, Jun => 6,
		 Jul => 7, Aug => 8, Sep => 9, Oct =>10, Nov =>11, Dec =>12);
use vars(%month_num);

sub get_iso_file3 {
    my($run_time,$data_source,$DEBUG,$desired_fcst_len,$start)=@_;
    my ($out_file,$type,$fcst_len);    

    unless(defined $desired_fcst_len) {
	die "must have a desired forecast len!\n";
    }
    my $suffix = ".grib";
    my $anal_dir;
    if($data_source eq "RR1h") {
	$anal_dir = "/whome/rtrr/rr/WRFDATE/postprd/";
    } elsif($data_source eq "FIM_4") {
#	$anal_dir = "/public/data/gsd/fim/nat/grib2/";
        $anal_dir ="/pan2/projects/fim-njet/FIM/FIMrun/fim_8_64_240_201501160000/post_C/fim/NAT/grib2/";
    } elsif($data_source eq "GFS_4") {
	$anal_dir = "/public/data/grids/gfs/0p5deg/grib2/";
    } elsif($data_source eq "FIM_130") {
	$anal_dir = "/pan2/projects/fim-njet/FIM/FIMrun/fim_8_64_240_WRFDATE00/post_C/130/NAT/grib2/";
    } elsif($data_source eq "GLMP") {
	$anal_dir = "/public/data/grids/lamp/2p5km/grib2/";
    } elsif($data_source eq "RAP_OPS_iso_242") {
	$anal_dir = "/public/data/grids/rap/242_alaska/grib2/";
    } elsif($data_source eq "RAP_NCOpara_iso_242") {
	$anal_dir = "/public/data/grids/rapv2/242_alaska/grib2/";
    } elsif($data_source eq "RRnc") {
	$anal_dir = "/whome/wrfruc/rr_nocyc/WRFDATE/postprd/";
    } elsif($data_source eq "RR1h_dev") {
	$anal_dir = "/whome/rtrr/rr_devel/WRFDATE/postprd/";
    } elsif($data_source eq "RR1h_dev2") {
	$anal_dir = "/whome/rtrr/rr_devel2/WRFDATE/postprd/";
    } elsif($data_source eq "HRRR") {
	$anal_dir = "/whome/rtrr/hrrr/WRFDATE/postprd/";
    } elsif($data_source eq "HRRR_OPS") {
#	$anal_dir = "/public/gsd/hrrr_ncep/conus/wrfprs/";
	$anal_dir = "/public/data/grids/hrrr/conus/wrfprs/grib2/";
    } elsif($data_source eq "Bak13") {
	$anal_dir = "/whome/rtruc/ruc_backup/ruc_presm/";
	$suffix = ".grib";
    } elsif($data_source eq "Dev13") {
	$anal_dir = "/whome/rtruc/ruc_devel/ruc_presm/";
	$suffix = ".grib";
    } elsif($data_source eq "Op13") {
	$anal_dir = "/public/data/grids/ruc/iso_130/grib2";
	$suffix = "";
    } elsif($data_source eq "RRrapx") {
	$anal_dir = "/public/data/grids/rr/iso_130/grib2";
	$suffix = "";
    } elsif($data_source eq "RAP_NCEP") {
	$anal_dir = "/public/data/grids/rap/iso_130/grib2";
	$suffix = "";
    } elsif($data_source eq "NAM") {
	$anal_dir = "/public/data/grids/nam/nh221/grib2";
	$suffix = "";
    } elsif($data_source eq "NAMnest_OPS_227") {
	$anal_dir = "/public/data/grids/nam/conusnest/grib2";
	$suffix = "";
    } elsif($data_source eq "RTMA_HRRR") {
        $anal_dir = "/home/rtrr/rtma/WRFDATE00/";
    } elsif($data_source eq "RTMA_HRRR_15min") {
        $anal_dir = "/home/rtrr/rtma_15min/WRFDATE00/";
    } else {
	$anal_dir = "${data_source}_grib_dir";
    }
    if ($DEBUG) {
	print "data source is $data_source. ";
	print "Looking in directory $anal_dir\n";
    }
    # the hardest part if to get the suffix
    if($anal_dir =~ /grib2/ ||
       $anal_dir =~ m|gsd/fim/grib| ||
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
    if($anal_dir =~ /WRFDATE/) {
	# replace with the date format used by WRF (FIM and RR)
	my $fim_date = sprintf("%04d%02d%02d%02d",
			       $year+1900,$mon+1,$mday,$hour);
	$anal_dir =~ s/WRFDATE/$fim_date/;
	my $base_file = sprintf("WRFNAT%02d.tm00",$desired_fcst_len);
	if($data_source =~ /^RAP/) {
	    if($desired_fcst_len == 0) {
		$base_file = sprintf("wrfprs_rr_%02d.al00",$desired_fcst_len);
	    } else {
		if($data_source eq "RRnc") {
		    $base_file = sprintf("wrfprs_rr_%02d.tm00",$desired_fcst_len);
		} else {
		    $base_file = sprintf("wrfprs_rr_%02d.grib1",$desired_fcst_len);
		}
	    }
	} elsif($data_source =~ /^RR/) {
	    if($desired_fcst_len == 0) {
		$base_file = sprintf("wrfprs_rr_%02d.al00",$desired_fcst_len);
	    } else {
		if($data_source eq "RRnc") {
		    $base_file = sprintf("wrfprs_rr_%02d.tm00",$desired_fcst_len);
		} else {
		    $base_file = sprintf("wrfprs_rr_%02d.grib1",$desired_fcst_len);
		}
	    }
	} elsif($data_source =~ /^HRRR/) {
		$base_file = sprintf("wrfprs_hrconus_%02d.grib1",$desired_fcst_len);

	} elsif($data_source =~ /^RTMA/) {
            $base_file = sprintf("wrftwo_hrconus_rtma.grib2");
	} elsif($data_source =~ /^FIM/) {
            $base_file = sprintf("%02d%03d%02d%02d%02d%02d",$year+1900-2000,$yday+1,$hour,0,0,$desired_fcst_len);
        }

	$filename = "${anal_dir}$base_file";
    } else {
	# RUC-style filename
	$filename = sprintf("${anal_dir}/%02d%03d%02d000%03d$suffix",
			       $year%100,$yday+1,$hour,
			       $desired_fcst_len);
	if($data_source eq "HRRR_ops") {
#        	print "weixue in hrrr_ops  $data_source\n";
                $base_file = sprintf("%02d%03d%02d00%02d00",$year%100,$yday+1,$hour,$desired_fcst_len);
         	$filename = "${anal_dir}$base_file";
#                exit;
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
