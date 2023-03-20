my %month_num = (Jan => 1, Feb => 2, Mar => 3, Apr => 4, May => 5, Jun => 6,
		 Jul => 7, Aug => 8, Sep => 9, Oct =>10, Nov =>11, Dec =>12);
use vars(%month_num);

sub my_timeout {
    print STDERR "timeout\n";
    die 1;
}

sub get_RR_prs_file_backfill {
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
	print "data source = $data_source\n";
    }
    unless(defined $desired_fcst_len) {
	print "TROUBLE: must define desired_fcst_len\n";
    }

    my $template = sprintf("wrfprs_rr_%02d.grib2",$desired_fcst_len);
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
    } elsif($data_source eq "HRRR_OPS_iso") {
	$anal_dir = "/lfs4/BMC/amb-verif/backfill/hrrr_ops";
	#$anal_dir = "/mnt/lfs1/BMC/public/data/grids/hrrr/conus/wrfprs/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "HRRRv3_EMC_iso") {
        $anal_dir = "/mnt/lfs1/BMC/public/data/grids/hrrrv3/conus/wrfprs/grib2";
        $template = sprintf("%02d%03d%02d%06d",
                            $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "HRRRv3_NCO_iso") {
        $anal_dir = "/mnt/lfs1/BMC/public/data/grids/hrrrv3_nco/conus/wrfprs/grib2";
        $template = sprintf("%02d%03d%02d%06d",
                            $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "HRRRv3_NCO_AK_iso") {
        $anal_dir = "/mnt/lfs1/BMC/public/data/grids/hrrrv3_nco/alaska/wrfprs/grib2";
        $template = sprintf("%02d%03d%02d%06d",
                            $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "HRRR_AKv4_EMC_iso") {
        $anal_dir = "/public/data/grids/hrrrv4/alaska/wrfprs/grib2";
        $template = sprintf("%02d%03d%02d%06d",
                            $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "HRRR_dev3_iso") {
	$anal_dir =
	    sprintf("/home/rtrr/hrrr_dev3/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
	$template = sprintf("wrfprs_hrconus_%02d.grib2",$desired_fcst_len);
    } elsif($data_source eq "HRRR_NEST_PLAINS_iso") {
	$anal_dir =
	    sprintf("/whome/rtrr/hrrr_nest2/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
	$template = sprintf("wrfprs_hrnest2_%02d.grib2",$desired_fcst_len);
    } elsif($data_source eq "HRRRE_mem1_iso") {
        $anal_dir = sprintf("/lfs1/BMC/wrfruc/HRRRE/forecast/%4d%2.2d%2.2d%2.2d/postprd_mem0001",
			$year+1900,$month+1,$mday,$hour);
	$template = sprintf("wrfprs_mem0001_%02d.grib2",$desired_fcst_len);
    } elsif($data_source eq "HRRRE_mem2_iso") {
        $anal_dir = sprintf("/lfs1/BMC/wrfruc/HRRRE/forecast/%4d%2.2d%2.2d%2.2d/postprd_mem0002",
			$year+1900,$month+1,$mday,$hour);
	$template = sprintf("wrfprs_mem0002_%02d.grib2",$desired_fcst_len);
    } elsif($data_source eq "HRRRE_mem3_iso") {
        $anal_dir = sprintf("/lfs1/BMC/wrfruc/HRRRE/forecast/%4d%2.2d%2.2d%2.2d/postprd_mem0003",
			$year+1900,$month+1,$mday,$hour);
	$template = sprintf("wrfprs_mem0003_%02d.grib2",$desired_fcst_len);
    } elsif($data_source eq "RRFS_NA_3km_dev1_HRRR_iso") {
        $anal_dir = sprintf("/lfs4/BMC/nrtrr/NCO_dirs/stmp/tmpnwprd/RRFS_NA_3km_dev1/%04d%02d%02d%02d/postprd/hrrr_grid",
                    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("RRFS_NA_3km.t%02dz.bgdawpf%03d.tm00.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "RRFS_B_iso") {
        $anal_dir = sprintf("/lfs4/BMC/amb-verif/backfill/rrfs_b/%04d%02d%02d%02d/postprd",
                    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("RRFS_CONUS.t%02dz.bgdawpf%03d.tm00.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "RAP_OPS_iso") {
	$anal_dir = "/public/data/grids/rap/full/wrfprs/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RAP_OPS_iso_130") {
	$anal_dir = "/public/data/grids/rap/iso_130/grib2";
	#$anal_dir = "/mnt/lfs1/BMC/public/data/grids/rap/iso_130/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RAPv4_EMC_iso") {
        $anal_dir = "/mnt/lfs1/BMC/public/data/grids/rapv4/full/wrfprs/grib2";
        $template = sprintf("%02d%03d%02d%06d",
                            $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RAPv4_EMC_iso_130") {
        $anal_dir = "/mnt/lfs1/BMC/public/data/grids/rapv4/iso_130/grib2";
        $template = sprintf("%02d%03d%02d%06d",
                            $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RAPv4_NCO_iso") {
        $anal_dir = "/mnt/lfs1/BMC/public/data/grids/rapv4_nco/full/wrfprs/grib2";
        $template = sprintf("%02d%03d%02d%06d",
                            $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RAPv4_NCO_iso_130") {
        $anal_dir = "/mnt/lfs1/BMC/public/data/grids/rapv4_nco/iso_130/grib2";
        $template = sprintf("%02d%03d%02d%06d",
                            $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RAPv5_NCO_iso") {
        $anal_dir = "/mnt/lfs1/BMC/public/data/grids/rapv5/full/wrfprs/grib2";
        $template = sprintf("%02d%03d%02d%06d",
                            $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RAPv5_NCO_iso_130") {
        $anal_dir = "/mnt/lfs1/BMC/public/data/grids/rapv5/iso_130/grib2";
        $template = sprintf("%02d%03d%02d%06d",
                            $year%100,$yday+1,$hour,$desired_fcst_len);
#    } elsif($data_source eq "RAPv5_NCO_iso") {
#        $anal_dir = sprintf("/mnt/lfs4/BMC/rtwbl/mhu/wcoss/nco/cycles/ncorap/%04d%02d%02d%02d/postprd/",
#                        $year+1900,$month+1,$mday,$hour);
#        $template = sprintf("rap.t%02dz.wrfprsf%02d.grib2",$hour,$desired_fcst_len);
#    } elsif($data_source eq "RAPv5_EMC_iso") {
#        $anal_dir = sprintf("/mnt/lfs4/BMC/rtwbl/mhu/wcoss/emc/cycles/ncorap/%04d%02d%02d%02d/postprd/",
#                        $year+1900,$month+1,$mday,$hour);
#        $template = sprintf("rap.t%02dz.wrfprsf%02d.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "HRRRv4_NCO_iso") {
        $anal_dir = "/mnt/lfs1/BMC/public/data/grids/hrrrv4/conus/wrfprs/grib2";
        $template = sprintf("%02d%03d%02d%06d",
                            $year%100,$yday+1,$hour,$desired_fcst_len);
#    } elsif($data_source eq "HRRRv4_NCO_iso") {
#        $anal_dir = sprintf("/mnt/lfs4/BMC/rtwbl/mhu/wcoss/nco/cycles/ncohrrr/%04d%02d%02d%02d/postprd/",
#                        $year+1900,$month+1,$mday,$hour);
#        $template = sprintf("hrrr.t%02dz.wrfprsf%02d.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "HRRR_AKv4_NCO_iso") {
#        $anal_dir = sprintf("/mnt/lfs4/BMC/rtwbl/mhu/wcoss/nco/cycles/ncohrrrak/%04d%02d%02d%02d/postprd/",
#                        $year+1900,$month+1,$mday,$hour);
#        $template = sprintf("hrrr.t%02dz.wrfprsf%02d.ak.grib2",$hour,$desired_fcst_len);
        $anal_dir = "/mnt/lfs1/BMC/public/data/grids/hrrrv4/alaska/wrfprs/grib2";
        $template = sprintf("%02d%03d%02d%06d",
                            $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "HRRRv4_EMC_iso") {
        $anal_dir = sprintf("/mnt/lfs4/BMC/rtwbl/mhu/wcoss/emc/cycles/ncohrrr/%04d%02d%02d%02d/postprd/",
                        $year+1900,$month+1,$mday,$hour);
        $template = sprintf("hrrr.t%02dz.wrfprsf%02d.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "HRRR_AKv4_EMC_iso") {
        $anal_dir = sprintf("/mnt/lfs4/BMC/rtwbl/mhu/wcoss/emc/cycles/ncohrrrak/%04d%02d%02d%02d/postprd/",
                        $year+1900,$month+1,$mday,$hour);
        $template = sprintf("hrrr.t%02dz.wrfprsf%02d.ak.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "RAPv3_NCO_iso_130") {
	$anal_dir = "/mnt/lfs1/BMC/public/data/grids/rapv3/iso_130/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "HRRRv2_NCO_iso") {
	$anal_dir = "/mnt/lfs1/BMC/public/data/grids/hrrrv2/conus/wrfprs/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "NAM_OPS_iso_221") {
	$anal_dir = "/public/data/grids/nam/nh221/grib2";
	#$anal_dir = "/mnt/lfs1/BMC/public/data/grids/nam/nh221/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RAP_iso_130") {
	$anal_dir =
	    sprintf("/whome/rtrr/rr/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
	$template = sprintf("wrfprs_130_%02d.grib2",$desired_fcst_len);
    } elsif($data_source eq "RTMA_3D_GSD_iso") {
        $anal_dir =
            sprintf("/whome/rtrr/rtma_3d/%4d%2.2d%2.2d%2.2d/postprd",
                    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("wrfprs_hrconus_%02d.grib2",$desired_fcst_len);
    } elsif($data_source eq "RTMA_3D_GSD_dev1_iso") {
        $anal_dir =
            sprintf("/whome/rtrr/rtma_3d_dev1/%4d%2.2d%2.2d%2.2d/postprd",
                    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("wrfprs_hrconus_%02d.grib2",$desired_fcst_len);
    } elsif($data_source eq "RTMA_3D_AK_iso") {
        $anal_dir =
            sprintf("/whome/rtrr/rtma_3d_ak/%4d%2.2d%2.2d%2.2d/postprd",
                    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("wrfprs_hralaska_%02d.grib2",$desired_fcst_len);
    } elsif($data_source eq "RTMA_3D_RU_EMC_iso") {
	$anal_dir = "/mnt/lfs1/BMC/public/data/grids/rtma_3d/conus/wrfsubhprs/grib2";
 	$template = sprintf("%02d%03d%02d00%04d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RTMA_3D_RU_GSD_iso") {
        $anal_dir =
            sprintf("/home/rtrr/rtma_3d_ru/%4d%2.2d%2.2d%2.2d00/postprd",
                    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("wrfprs_hrconus_%02d.grib2",$desired_fcst_len);
    } elsif($data_source eq "RR1h_dev") {
	$anal_dir =
	    sprintf("/whome/wrfruc/rr_devel/%4d%2.2d%2.2d%2.2d/postprd",
		$year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "RRnc") {
	$anal_dir =
	    sprintf("/whome/wrfruc/rr_nocyc/%4d%2.2d%2.2d%2.2d/postprd",
		$year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "GFS_OPS_iso") {
	$anal_dir = "/public/data/grids/gfs/0p5deg/netcdf";
	#$anal_dir = "/mnt/lfs1/BMC/public/data/grids/gfs/0p5deg/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "FIM_iso_4") {
	$anal_dir = "/mnt/lfs1/BMC/public/gsd/fim/netcdf";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } else {
	$anal_dir =
	    sprintf("retro_runs/$data_source/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
	if($data_source =~ /^RAP/) {
	    $template = sprintf("wrfprs_rr_%02d.grib2",$desired_fcst_len);
	} elsif($data_source =~ /^HRRR/) {
	    $template = sprintf("wrfprs_hrconus_%02d.grib2",$desired_fcst_len);
	} elsif($data_source =~ /^RRFS_NA_13km/) {
	    $template = sprintf("RRFS_NA_13km.t%02dz.bgdawp%02d.tm%02d",$hour,$desired_fcst_len,$hour);
	}
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
