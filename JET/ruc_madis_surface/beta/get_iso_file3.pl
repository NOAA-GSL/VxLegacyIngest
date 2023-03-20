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
#	$anal_dir = "/whome/rtrr/rr/WRFDATE/postprd/";
	$anal_dir = "/whome/rtrr/rap/WRFDATE/postprd/";
    } elsif($data_source eq "FIM_4") {
	$anal_dir = "/public/data/gsd/fim/nat/grib2/";
	#$anal_dir = "/public/data/gsd/fim/nat/grib2/";
    } elsif($data_source eq "GFS_4") {
	$anal_dir = "/public/data/grids/gfs/0p5deg/grib2/";
	#$anal_dir = "/public/data/grids/gfs/0p5deg/grib2/";
    } elsif($data_source eq "FV3_GFS_EMC") {
	$anal_dir = "/public/data/grids/fv3gfs_emc/0p25deg/grib2/";
	#$anal_dir = "/public/data/grids/gfs/0p5deg/grib2/";
    } elsif($data_source eq "NAVGEM_HIWPP_4") {
	$anal_dir = "/public/data/grids/navgem/0p5/grib2/";
	#$anal_dir = "/public/data/grids/navgem/0p5/grib2/";
    } elsif($data_source eq "FIM_130") {
	$anal_dir = "/pan2/projects/fim-njet/FIM/FIMrun/fim_8_64_240_WRFDATE00/post_C/130/NAT/grib2/";
    } elsif($data_source eq "GLMP") {
	#$anal_dir = "/pan2/projects/public/data/grids/lamp/2p5km/grib2/";
	$anal_dir = "/public/data/grids/lamp/2p5km/grib2/";
    } elsif($data_source eq "RAP_OPS_iso_242") {
	#$anal_dir = "/pan2/projects/public/data/grids/rap/242_alaska/grib2/";
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
    } elsif($data_source eq "HRRR_NEST_PLAINS") {
	$anal_dir = "/whome/rtrr/hrrr_nest2/WRFDATE/postprd/";
    } elsif($data_source eq "HRRR_NEST_PLAINS_dev") {
	$anal_dir = "/whome/rtrr/hrrr_nest2_dev/WRFDATE/postprd/";
    } elsif($data_source eq "HRRR_WFIP2") {
        $anal_dir = "/whome/rtrr/hrrr_wfip2_databasedir/run/WRFDATE/postprd/conus/";
    } elsif($data_source eq "HRRR_NREL") {
        $anal_dir = "/public/data/gsd/hrrr_nrel/conus/wrfnat/";
        $suffix = "";
    } elsif($data_source eq "HRRR_AK") {
        $anal_dir = "/whome/rtrr/hrrr_ak/WRFDATE/postprd/";
    } elsif($data_source eq "HRRR_AK_dev") {
        $anal_dir = "/lfs1/BMC/wrfruc/HRRR_AK_dev/run/WRFDATE/postprd/";
    } elsif($data_source eq "HRRR_HI") {
        $anal_dir = "/whome/rtrr/hrrr_hi/WRFDATE/postprd/";
    } elsif($data_source eq "HRRR_dev3") {
        $anal_dir = "/home/rtrr/hrrr_dev3/WRFDATE/postprd/";
        #$anal_dir = "/lfs1/projects/wrfruc/jdduda/HRRRdev3/WRFDATE/";
    } elsif($data_source eq "HRRRDAS") {
        $anal_dir = "/lfs1/BMC/wrfruc/HRRRE/cycle/WRFDATE/postprd_mem0000/";
    } elsif($data_source eq "HRRRE_mem1") {
        $anal_dir = "/lfs1/BMC/wrfruc/HRRRE/forecast/WRFDATE/postprd_mem0001/";
    } elsif($data_source eq "HRRRE_mem2") {
        $anal_dir = "/lfs1/BMC/wrfruc/HRRRE/forecast/WRFDATE/postprd_mem0002/";
    } elsif($data_source eq "HRRRE_mem3") {
        $anal_dir = "/lfs1/BMC/wrfruc/HRRRE/forecast/WRFDATE/postprd_mem0003/";
    } elsif($data_source eq "NAM_NEST_AK") {
        $anal_dir = "/public/data/grids/nam/aknest/grib2/";
        $suffix = "";
    } elsif($data_source eq "NAM_NEST_HI") {
        $anal_dir = "/public/data/grids/nam/hawaiinest/grib2/";
        $suffix = "";
    } elsif($data_source eq "HRRR_OPS") {
#	$anal_dir = "/public/gsd/hrrr_ncep/conus/wrfprs/";
	#$anal_dir = "/pan2/projects/public/data/grids/hrrr/conus/wrfprs/grib2/";
	$anal_dir = "/public/data/grids/hrrr/conus/wrfprs/grib2/";
    } elsif($data_source eq "HRRR_AK_OPS") {
	$anal_dir = "/public/data/grids/hrrrak/alaska/wrfprs/grib2/";
    } elsif($data_source eq "HRRR_AKv4_EMC") {
	$anal_dir = "/public/data/grids/hrrrv4/alaska/wrfsfc/grib2/";
    } elsif($data_source eq "HRRRv3_EMC") {
	$anal_dir = "/public/data/grids/hrrrv3/conus/wrfprs/grib2/";
    } elsif($data_source eq "HRRRv4_EMC") {
	$anal_dir = "/public/data/grids/hrrrv4/conus/wrfprs/grib2/";
    } elsif($data_source eq "HRRRv3_NCO") {
	$anal_dir = "/public/data/grids/hrrrv3_nco/conus/wrfprs/grib2/";
    } elsif($data_source eq "HRRRv3_NCO_AK") {
	$anal_dir = "/public/data/grids/hrrrv3_nco/alaska/wrfprs/grib2/";
    } elsif($data_source eq "HRRRv4_NCO") {
	$anal_dir = "/mnt/lfs1/BMC/rtwbl/mhu/wcoss/nco/cycles/ncohrrr/WRFDATE/postprd/";
    } elsif($data_source eq "HRRR_AKv4_NCO") {
	$anal_dir = "/mnt/lfs1/BMC/rtwbl/mhu/wcoss/nco/cycles/ncohrrrak/WRFDATE/postprd/";
    } elsif($data_source eq "RAPv4_EMC") {
	$anal_dir = "/public/data/grids/rapv4/full/wrfprs/grib2/";
    } elsif($data_source eq "RAPv4_EMC_130") {
	$anal_dir = "/public/data/grids/rapv4/iso_130/grib2/";
    } elsif($data_source eq "RAPv4_NCO") {
	$anal_dir = "/public/data/grids/rapv4_nco/full/wrfprs/grib2/";
    } elsif($data_source eq "RAPv4_NCO_130") {
	$anal_dir = "/public/data/grids/rapv4_nco/iso_130/grib2/";
    } elsif($data_source eq "RAPv5_EMC") {
	$anal_dir = "/public/data/grids/rapv5/full/wrfprs/grib2/";
    } elsif($data_source eq "RAPv5_EMC_130") {
	$anal_dir = "/public/data/grids/rapv5/iso_130/grib2/";
    } elsif($data_source eq "RAPv5_NCO") {
	$anal_dir = "/mnt/lfs1/BMC/rtwbl/mhu/wcoss/nco/cycles/ncorap/WRFDATE/postprd/";
    } elsif($data_source eq "RRFS_dev1") {
	$anal_dir = "/lfs4/BMC/nrtrr/RRFS/conus_FV3GFS/run/WRFDATE/postprd/";
    } elsif($data_source eq "RRFS_dev2") {
	$anal_dir = "/lfs4/BMC/nrtrr/RRFS/conus_FV3GFS_hord5/run/WRFDATE/postprd/";
    } elsif($data_source eq "RRFS_dev3") {
	$anal_dir = "/lfs4/BMC/nrtrr/RRFS/conus_HRRRX_hord5/run/WRFDATE/postprd/";
    } elsif($data_source eq "RRFS_dev4") {
	$anal_dir = "/lfs4/BMC/nrtrr/RRFS/conus_HRRRX/run/WRFDATE/postprd/";
    } elsif($data_source eq "RRFS_AK") {
	$anal_dir = "/lfs4/BMC/nrtrr/RRFS/alaska/run/WRFDATE/postprd/";
    } elsif($data_source eq "HRRRv2_NCO") {
	$anal_dir = "/public/data/grids/hrrrv2/conus/wrfprs/grib2/";
	#$anal_dir = "/public/data/grids/hrrrv2/conus/wrfprs/grib2/";
    } elsif($data_source eq "RTMA_GSD") {
        $anal_dir = "/whome/rtrr/rtma_15min/WRFDATE00/";
    } elsif($data_source eq "RTMA_GSD_dev1") {
        $anal_dir = "/whome/rtrr/rtma_15min_dev1/WRFDATE00/";
   # } elsif($data_source eq "RUA") {
	#$anal_dir = "/lfs1/projects/nrtrr/RUA/run/WRFDATE/postprd/";
    } elsif($data_source eq "RUA") {
	$anal_dir = "/whome/rtrr/rtma_3d/WRFDATE/postprd/";
    } elsif($data_source eq "RTMA_GSD_3D_bl") {
	$anal_dir = "/whome/rtrr/rtma_3d/WRFDATE/smtiprd/";
    } elsif($data_source eq "RTMA_GSD_3D_nb") {
	$anal_dir = "/whome/rtrr/rtma_3d/WRFDATE/smtiprd/";
    } elsif($data_source eq "RTMA_GSD_3D_dev1_bl") {
	$anal_dir = "/whome/rtrr/rtma_3d_dev1/WRFDATE/smtiprd/";
    } elsif($data_source eq "RTMA_GSD_3D_dev1_nb") {
	$anal_dir = "/whome/rtrr/rtma_3d_dev1/WRFDATE/smtiprd/";
    } elsif($data_source eq "RUA_dev1") {
	$anal_dir = "/whome/rtrr/rtma_3d_dev1/WRFDATE/postprd/";
    } elsif($data_source eq "RUA_AK") {
	$anal_dir = "/lfs1/BMC/nrtrr/RUA_AK/run/WRFDATE/postprd/";
    } elsif($data_source eq "RTMA_OPS_smartinit_hrrr") {
        $anal_dir = "/public/data/grids/hrrr/smart/";
    } elsif($data_source eq "RTMA_OPS_smartinit_rap") {
        $anal_dir = "/public/data/grids/rap/smart/";
    } elsif($data_source eq "RTMA_OPS") {
        $anal_dir = "/public/data/grids/rtma/2p5km_ru/grib2/";
    } elsif($data_source eq "RTMA_OPS") {
        $anal_dir = "/public/data/grids/urma/2p5km/grib2/";
    } elsif($data_source eq "RTMA_OPS_hourly") {
        $anal_dir = "/public/data/grids/rtma/2p5km/grib2/";
    } elsif($data_source eq "RTMA_v2_7_EMC") {
        $anal_dir = "/public/data/grids/rtma_v2.7.0/2p5km/grib2/";
    } elsif($data_source eq "RTMA_v2_7_RU_EMC") {
        $anal_dir = "/public/data/grids/rtma_v2.7.0/2p5km_ru/grib2/";
    } elsif($data_source eq "RTMA_3D_RU_EMC") {
        $anal_dir = "/public/data/grids/rtma_3d/conus/wrfsubhprs/grib2/";
    } elsif($data_source eq "RTMA_3D_RU_GSD") {
        $anal_dir = "/home/rtrr/rtma_3d_ru/WRFDATE00/postprd/";
    } elsif($data_source eq "RTMA_3D_AK") {
        $anal_dir = "/whome/rtrr/rtma_3d_ak/WRFDATE/postprd/";
    } elsif($data_source eq "Bak13") {
	$anal_dir = "/whome/rtruc/ruc_backup/ruc_presm/";
	$suffix = ".grib";
    } elsif($data_source eq "Dev13") {
	$anal_dir = "/whome/rtruc/ruc_devel/ruc_presm/";
	$suffix = ".grib";
#    } elsif($data_source eq "Op13") {
#	$anal_dir = "/public/data/grids/ruc/iso_130/grib2";
#	$suffix = "";
    } elsif($data_source eq "RRrapx") {
	$anal_dir = "/public/data/grids/rap/iso_130/grib2";
	$suffix = "";
    } elsif($data_source eq "RAP_NCEP") {
	$anal_dir = "/public/data/grids/rap/iso_130/grib2";
	$suffix = "";
    } elsif($data_source eq "RAP_NCEP_full") {
	$anal_dir = "/public/data/grids/rap/full/wrfnat/grib2";
	$suffix = "";
    } elsif($data_source eq "RAPv3_NCO") {
	$anal_dir = "/public/data/grids/rapv3/full/wrfprs/grib2";
	#$anal_dir = "/public/data/grids/rapv3/full/wrfprs/grib2";
	$suffix = "";
    } elsif($data_source eq "RAPv3_NCO_iso_130") {
	$anal_dir = "/public/data/grids/rapv3/iso_130/grib2";
	#$anal_dir = "/public/data/grids/rapv3/iso_130/grib2";
	$suffix = "";
    } elsif($data_source eq "NAM") {
	#$anal_dir = "/pan2/projects/public/data/grids/nam/nh221/grib2";
	$anal_dir = "/public/data/grids/nam/nh221/grib2";
	$suffix = "";
    } elsif($data_source eq "NAMnest_OPS_227") {
	$anal_dir = "/public/data/grids/nam/conusnest/grib2";
	#$anal_dir = "/public/data/grids/nam/conusnest/grib2";
	$suffix = "";
    } elsif($data_source eq "RTMA_HRRR") {
        $anal_dir = "/home/rtrr/rtma_15min/WRFDATE00/";
    } elsif($data_source eq "RTMA_HRRR_15min") {
        $anal_dir = "/home/rtrr/rtma_15min/WRFDATE00/";
    } elsif($data_source eq "RTMA_dev1") {
        $anal_dir = "/lfs1/BMC/nrtrr/RTMA_dev1/run/WRFDATE00/";
    } elsif($data_source eq "SAR_FV3_GSD") {
        $anal_dir = "/public/data/gsd/fv3-sar/conus/bgrd3d/";
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

    my $prev_hour = $hour-1;
    if ($prev_hour < 0) {
        $prev_hour = 23;
    }

    my $filename;
    if($anal_dir =~ /WRFDATE/) {
	# replace with the date format used by WRF (FIM and RR)
	my $fim_date = sprintf("%04d%02d%02d%02d",
			       $year+1900,$mon+1,$mday,$hour);
	$anal_dir =~ s/WRFDATE/$fim_date/;
	my $base_file = sprintf("WRFNAT%02d.tm00",$desired_fcst_len);
        if($data_source eq "RAPv5_NCO") {
                $base_file = sprintf("rap.t%02dz.wrfprsf%02d.grib2",$hour,$desired_fcst_len);
	} elsif($data_source =~ /^RAP/) {
	    if($desired_fcst_len == 0) {
		$base_file = sprintf("wrfprs_rr_%02d.al00",$desired_fcst_len);
	    } else {
		if($data_source eq "RRnc") {
		    $base_file = sprintf("wrfprs_rr_%02d.tm00",$desired_fcst_len);
		} else {
		    $base_file = sprintf("wrfprs_rr_%02d.grib2",$desired_fcst_len);
		}
	    }
        } elsif($data_source eq "HRRRv4_NCO") {
                $base_file = sprintf("hrrr.t%02dz.wrfprsf%02d.grib2",$hour,$desired_fcst_len);
        } elsif($data_source eq "RRFS_AK") {
                $base_file = sprintf("RRFS_AK.t%02dz.bgdawp%02d.tm%02d",$hour,$desired_fcst_len,$hour);
        } elsif($data_source =~  /^RRFS_dev/) {
                $base_file = sprintf("RRFS_CONUS.t%02dz.bgdawp%02d.tm%02d",$hour,$desired_fcst_len,$hour);
        } elsif($data_source eq "HRRR_AKv4_NCO") {
                $base_file = sprintf("hrrr.t%02dz.wrfprsf%02d.ak.grib2",$hour,$desired_fcst_len);
        } elsif($data_source eq "HRRR_WFIP2") {
                $base_file = sprintf("wrfnat_conus_%02d00.grib2",$desired_fcst_len);
        } elsif($data_source eq "HRRR_NEST_PLAINS") {
                $base_file = sprintf("wrftwo_hrnest2_%02d.grib2",$desired_fcst_len);
        } elsif($data_source eq "HRRR_NEST_PLAINS_dev") {
                $base_file = sprintf("wrftwo_hrnest2_%02d.grib2",$desired_fcst_len);
        } elsif($data_source eq "HRRRDAS") {
                $base_file = sprintf("wrftwo_conus_mem0000_%02d.grib2",$desired_fcst_len);
        } elsif($data_source eq "HRRRE_mem1") {
                $base_file = sprintf("wrfnat_mem0001_%02d.grib2",$desired_fcst_len);
        } elsif($data_source eq "HRRRE_mem2") {
                $base_file = sprintf("wrfnat_mem0002_%02d.grib2",$desired_fcst_len);
        } elsif($data_source eq "HRRRE_mem3") {
                $base_file = sprintf("wrfnat_mem0003_%02d.grib2",$desired_fcst_len);
       # } elsif($data_source eq "HRRR_dev3") {
       #         $base_file = sprintf("wrftwo_hrconus_%02d.grib2",$desired_fcst_len);
        } elsif($data_source eq "HRRR_AK") {
                $base_file = sprintf("wrfnat_hralaska_%02d.grib2",$desired_fcst_len);
        } elsif($data_source eq "HRRR_AK_dev") {
                $base_file = sprintf("wrftwo_hralaska_%02d.grib2",$desired_fcst_len);
        } elsif($data_source eq "HRRR_HI") {
                $base_file = sprintf("wrfnat_hrhawaii_%02d.grib2",$desired_fcst_len);
	} elsif($data_source eq "RUA") {
		$base_file = sprintf("wrftwo_hrconus_%02d.grib2",$desired_fcst_len);
	} elsif($data_source eq "RUA_dev1") {
		$base_file = sprintf("wrftwo_hrconus_%02d.grib2",$desired_fcst_len);
	} elsif($data_source eq "RUA_AK") {
		$base_file = sprintf("wrftwo_hrconus_%02d.grib2",$desired_fcst_len);
	} elsif($data_source eq "RTMA_3D_AK") {
		$base_file = sprintf("wrftwo_hrconus_%02d.grib2",$desired_fcst_len);
        } elsif($data_source eq "RTMA_3D_RU_GSD") {
                $base_file = sprintf("wrftwo_hrconus_%02d.grib2",$desired_fcst_len);
	} elsif($data_source eq "RTMA_GSD_3D_dev1_bl") {
                $base_file = sprintf("hrrr.t%02dz.smarthrrrconusf00_bl.grib2",$hour);
	} elsif($data_source eq "RTMA_GSD_3D_bl") {
                $base_file = sprintf("hrrr.t%02dz.smarthrrrconusf00_bl.grib2",$hour);
	} elsif($data_source eq "RTMA_GSD_3D_dev1_nb") {
                $base_file = sprintf("hrrr.t%02dz.smarthrrrconusf00_nb.grib2",$hour);
	} elsif($data_source eq "RTMA_GSD_3D_nb") {
                $base_file = sprintf("hrrr.t%02dz.smarthrrrconusf00_nb.grib2",$hour);
        } elsif($data_source =~ /^HRRR_AK/) {
                $base_file = sprintf("wrfprs_hralaska_%02d.grib2",$desired_fcst_len);
        } elsif($data_source =~ /^HRRRAK/) {
                $base_file = sprintf("wrfprs_hralaska_%02d.grib2",$desired_fcst_len);
	} elsif($data_source =~ /^HRRR/) {
		$base_file = sprintf("wrfprs_hrconus_%02d.grib2",$desired_fcst_len);
	} elsif($data_source =~ /^RTMA/) {
            $base_file = sprintf("wrftwo_hrconus_rtma.grib2");
	} elsif($data_source =~ /^FIM/) {
            $base_file = sprintf("%02d%03d%02d%02d%02d%02d",$year+1900-2000,$yday+1,$hour,0,0,$desired_fcst_len);
	} elsif($data_source =~ /^RR/) {
	    if($desired_fcst_len == 0) {
		$base_file = sprintf("wrfprs_rr_%02d.al00.grb2",$desired_fcst_len);
	    } else {
		if($data_source eq "RRnc") {
		    $base_file = sprintf("wrfprs_rr_%02d.tm00",$desired_fcst_len);
		} else {
		    $base_file = sprintf("wrfprs_rr_%02d.grib2",$desired_fcst_len);
		}
	    }
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
	} 
	if($data_source eq "HRRR_NREL") {
                $base_file = sprintf("%02d%03d%02d%02d%02d%02d",$year+1900-2000,$yday+1,$hour,0,$desired_fcst_len,0);
       	        $filename = "${anal_dir}$base_file";
#                exit;
	}
        if($data_source eq "RTMA_OPS") {
            $anal_dir = sprintf("/public/data/grids/rtma/2p5km_ru/grib2/");
            $base_file = sprintf("%02d%03d%02d00%06d",
                                $year%100,$yday+1,$hour,$desired_fcst_len);
                $filename = "${anal_dir}$base_file";
        }
        if($data_source eq "RTMA_v2_7_RU_EMC") {
            $anal_dir = sprintf("/public/data/grids/rtma_v2.7.0/2p5km_ru/grib2/");
            $base_file = sprintf("%02d%03d%02d00%06d",
                                $year%100,$yday+1,$hour,$desired_fcst_len);
                $filename = "${anal_dir}$base_file";
        }
	if($data_source eq "RTMA_OPS_smartinit_hrrr") {
                $base_file = sprintf("%04d%03d%02d00.rtma2p5.t%02dz.hrrr.t%02dz.smarthrrrconusf%02d.grib2.%04d%02d%02d",$year+1900,$yday+1,$hour,$hour,$prev_hour,$desired_fcst_len,$year+1900,$mon+1,$mday);
                $filename = "${anal_dir}$base_file";
	} 
        if($data_source eq "RTMA_OPS_smartinit_rap") {
                $base_file = sprintf("%04d%03d%02d00.rtma2p5.t%02dz.rap.t%02dz.smartrapconusf%02d.grib2.%04d%02d%02d",$year+1900,$yday+1,$hour,$hour,$prev_hour,$desired_fcst_len,$year+1900,$mon+1,$mday);
                $filename = "${anal_dir}$base_file";
        }
        if($data_source eq "RTMA_3D_RU_EMC") {
            $anal_dir = sprintf("/public/data/grids/rtma_3d/conus/wrfsubhprs/grib2/");
            $base_file = sprintf("%02d%03d%02d00%04d",
                                $year%100,$yday+1,$hour,$desired_fcst_len);
                $filename = "${anal_dir}$base_file";
        }
        if($data_source eq "URMA_OPS") {
            $anal_dir = sprintf("/public/data/grids/urma/2p5km/grib2/");
            $base_file = sprintf("%02d%03d%02d%06d",
                                $year%100,$yday+1,$hour,$desired_fcst_len);
                $filename = "${anal_dir}$base_file";
        }
        if($data_source eq "SAR_FV3_GSD") {
            $anal_dir = sprintf("/public/data/gsd/fv3-sar/conus/bgrd3d/");
            $base_file = sprintf("%02d%03d%02d%04d00",
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
