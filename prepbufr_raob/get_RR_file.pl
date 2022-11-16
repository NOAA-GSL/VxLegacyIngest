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
    print "data source: $data_source\n";
    if($data_source eq "RAP20") {
	$anal_dir = "/public/data/grids/rap/hyb_A252/grib2";
	#$anal_dir = "/pan2/projects/public/data/grids/rap/hyb_A252/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RAP_OPS_130") {
	$anal_dir = "/public/data/grids/rap/hyb_130/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RAP_OPS_iso") {
	$anal_dir = "/public/data/grids/rap/full/wrfprs/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RAPv3_EMC_130") {
	$anal_dir = "/public/data/grids/rapv3/hyb_130/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RAPv4_EMC_130") {
	$anal_dir = "/public/data/grids/rapv4/hyb_130/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RAPv4_EMC_130_iso") {
	$anal_dir = "/public/data/grids/rapv4/iso_130/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RAPv4_EMC_iso") {
	$anal_dir = "/public/data/grids/rapv4/full/wrfprs/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RAPv4_EMC") {
	$anal_dir = "/public/data/grids/rapv4/full/wrfnat/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RAPv4_NCO_130") {
	$anal_dir = "/public/data/grids/rapv4_nco/hyb_130/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RAPv4_NCO_130_iso") {
	$anal_dir = "/public/data/grids/rapv4_nco/iso_130/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RAPv4_NCO_iso") {
	$anal_dir = "/public/data/grids/rapv4_nco/full/wrfprs/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RAPv4_NCO") {
	$anal_dir = "/public/data/grids/rapv4_nco/full/wrfnat/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RAPv5_NCO_130") {
	$anal_dir = "/public/data/grids/rapv5/hyb_130/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RAPv5_NCO_130_iso") {
	$anal_dir = "/public/data/grids/rapv5/iso_130/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RAPv5_NCO_iso") {
	$anal_dir = "/public/data/grids/rapv5/full/wrfprs/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RAPv5_NCO") {
	$anal_dir = "/public/data/grids/rapv5/full/wrfnat/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RAP_NCO_gfsv16_test_iso") {
        $anal_dir = sprintf("/mnt/lfs4/BMC/rtwbl/mhu/wcoss/nco/cycles/ncorap/%04d%02d%02d%02d/postprd/",
                        $year+1900,$month+1,$mday,$hour);
        $template = sprintf("rap.t%02dz.wrfprsf%02d.grib2",$hour,$desired_fcst_len);
#    } elsif($data_source eq "RAP_NCO_130_iso") {
#        $anal_dir = sprintf("/mnt/lfs4/BMC/rtwbl/mhu/wcoss/nco/cycles/ncorap/%04d%02d%02d%02d/postprd/",
#                        $year+1900,$month+1,$mday,$hour);
#        $template = sprintf("rap.t%02dz.awp130pgrbf%02d.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "RAPv5_EMC_iso") {
        $anal_dir = sprintf("/mnt/lfs4/BMC/rtwbl/mhu/wcoss/emc/cycles/ncorap/%04d%02d%02d%02d/postprd/",
                        $year+1900,$month+1,$mday,$hour);
        $template = sprintf("rap.t%02dz.wrfprsf%02d.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "RAPv5_EMC_130_iso") {
        $anal_dir = sprintf("/mnt/lfs4/BMC/rtwbl/mhu/wcoss/emc/cycles/ncorap/%04d%02d%02d%02d/postprd/",
                        $year+1900,$month+1,$mday,$hour);
        $template = sprintf("rap.t%02dz.awp130pgrbf%02d.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "RRFS_A") {
        $anal_dir =
            sprintf("/lfs4/BMC/rtwbl/mhu/wcoss/emc/rrfs/rrfs_a.%04d%02d%02d/%02d",
                    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("RRFS_CONUS.t%02dz.bgrd3df%03d.tm00.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "RRFS_A_iso") {
        $anal_dir =
            sprintf("/lfs4/BMC/rtwbl/mhu/wcoss/emc/rrfs/rrfs_a.%04d%02d%02d/%02d",
                    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("RRFS_CONUS.t%02dz.bgdawpf%03d.tm00.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "RRFS_B") {
        $anal_dir =
            sprintf("/lfs4/BMC/nrtrr/NCO_dirs/ptmp/com/RRFS_CONUS/para/RRFS_conus_3km.%04d%02d%02d/%02d",
                    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("RRFS_CONUS.t%02dz.bgrd3df%03d.tm00.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "RRFS_B_iso") {
        $anal_dir =
            sprintf("/lfs4/BMC/nrtrr/NCO_dirs/ptmp/com/RRFS_CONUS/para/RRFS_conus_3km.%04d%02d%02d/%02d",
                    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("RRFS_CONUS.t%02dz.bgdawpf%03d.tm00.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "RRFS_AK") {
        $anal_dir = sprintf("/home/rtrr/rrfs/ptmp/com/RRFS_AK/para/RRFS_AK.%04d%02d%02d/%02d",
                        $year+1900,$month+1,$mday,$hour);
        $template = sprintf("RRFS_AK.t%02dz.bgrd3df%03d.tm%02d.grib2",$hour,$desired_fcst_len,$hour);
    } elsif($data_source eq "RRFS_AK_iso") {
        $anal_dir = sprintf("/home/rtrr/rrfs/ptmp/com/RRFS_AK/para/RRFS_AK.%04d%02d%02d/%02d",
                        $year+1900,$month+1,$mday,$hour);
        $template = sprintf("RRFS_AK.t%02dz.bgdawpf%03d.tm%02d.grib2",$hour,$desired_fcst_len,$hour);
    } elsif($data_source eq "RRFS_AK_dev2") {
        $anal_dir = sprintf("/home/rtrr/rrfs/ptmp/com/RRFS_AK/para/RRFS_AK_dev2.%04d%02d%02d/%02d",
                        $year+1900,$month+1,$mday,$hour);
        $template = sprintf("RRFS_AK.t%02dz.bgrd3df%03d.tm%02d.grib2",$hour,$desired_fcst_len,$hour);
    } elsif($data_source eq "RRFS_AK_dev2_iso") {
        $anal_dir = sprintf("/home/rtrr/rrfs/ptmp/com/RRFS_AK/para/RRFS_AK_dev2.%04d%02d%02d/%02d",
                        $year+1900,$month+1,$mday,$hour);
        $template = sprintf("RRFS_AK.t%02dz.bgdawpf%03d.tm%02d.grib2",$hour,$desired_fcst_len,$hour);
    } elsif($data_source eq "HRRRv3_EMC_iso") {
	$anal_dir = "/public/data/grids/hrrrv3/conus/wrfprs/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "HRRRv3_EMC") {
	$anal_dir = "/public/data/grids/hrrrv3/conus/wrfnat/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "HRRRv4_NCO_iso") {
	$anal_dir = "/public/data/grids/hrrrv4/conus/wrfprs/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "HRRRv4_NCO") {
	$anal_dir = "/public/data/grids/hrrrv4/conus/wrfnat/grib2";
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
    } elsif($data_source eq "HRRR_NCO_gfsv16_test_iso") {
        $anal_dir = sprintf("/mnt/lfs4/BMC/rtwbl/mhu/wcoss/nco/cycles/ncohrrr/%04d%02d%02d%02d/postprd/",
                        $year+1900,$month+1,$mday,$hour);
        $template = sprintf("hrrr.t%02dz.wrfprsf%02d.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "HRRR_AK_NCO_gfsv16_test_iso") {
        $anal_dir = sprintf("/mnt/lfs4/BMC/rtwbl/mhu/wcoss/nco/cycles/ncohrrrak/%04d%02d%02d%02d/postprd/",
                        $year+1900,$month+1,$mday,$hour);
        $template = sprintf("hrrr.t%02dz.wrfprsf%02d.ak.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "HRRR_AKv4_NCO_iso") {
        $anal_dir = "/public/data/grids/hrrrv4/alaska/wrfprs/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
#        $anal_dir = sprintf("/mnt/lfs4/BMC/rtwbl/mhu/wcoss/nco/cycles/ncohrrrak/%04d%02d%02d%02d/postprd/",
#                        $year+1900,$month+1,$mday,$hour);
#        $template = sprintf("hrrr.t%02dz.wrfprsf%02d.ak.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "HRRR_AKv4_NCO") {
        $anal_dir = "/public/data/grids/hrrrv4/alaska/wrfnat/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "HRRRv3_NCO_iso") {
	$anal_dir = "/public/data/grids/hrrrv3_nco/conus/wrfprs/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "HRRRv3_NCO") {
	$anal_dir = "/public/data/grids/hrrrv3_nco/conus/wrfnat/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "HRRRv3_NCO_AK_iso") {
	$anal_dir = "/public/data/grids/hrrrv3_nco/alaska/wrfprs/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "HRRRv3_NCO_AK") {
	$anal_dir = "/public/data/grids/hrrrv3_nco/alaska/wrfnat/grib2";
 	$template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "FV3_GFS_EMC") {
	$anal_dir = "/public/data/grids/fv3gfs_emc/0p25deg/grib2";
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
	    sprintf("/public/data/grids/rapv3/full/wrfnat/grib2");

   } elsif($data_source eq "RAP") {
       $anal_dir =
	    sprintf("/whome/rtrr/rr/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
       # change to grib2 for full RAP domain
       $template = sprintf("wrfnat_rr_%02d.grib2",$desired_fcst_len);
       if($special_type eq "analysis") {
	   $template =~ s/\.grib2$/\.al00.grb2/;
	}


   } elsif($data_source =~ /^RAP/ ||
	   $data_source eq "RR1h" ||
	   $data_source eq "RAP_iso_130" ||
	   $data_source eq "RR1hB" ||  # test of corrected ij for rotLL (was off by 1)
	   $data_source eq "RR1hC") {  # duplicat of RR1h, just for checking
       $anal_dir =
	    sprintf("/whome/rtrr/rr/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
   } elsif($data_source eq "GFS") {
       $anal_dir = "/public/data/grids/gfs/0p25deg/grib2";
       $template = sprintf("%02d%03d%02d%06d",
			    $year%100,$yday+1,$hour,$desired_fcst_len);
    } elsif($data_source eq "RR1h_dev" ||
	    $data_source eq "RR1h_dev130" ||
	    $data_source eq "isoRR1h_dev") {
	$anal_dir =
	    sprintf("/whome/rtrr/rr_devel/%4d%2.2d%2.2d%2.2d/postprd",
		$year+1900,$month+1,$mday,$hour);

    } elsif($data_source eq "SAR_FV3_GSD_iso") {
	$anal_dir = sprintf("/public/data/gsd/fv3-sar/conus/bgdawp/");

    } elsif($data_source eq "SAR_FV3_GSD") {
	$anal_dir = sprintf("/public/data/gsd/fv3-sar/conus/bgrd3d/");

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
	    sprintf("/lfs1/BMC/nrtrr/RUA/run/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "RUA_AK_iso") {
        $anal_dir = 
	    sprintf("/lfs1/BMC/nrtrr/RUA_AK/run/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
    } elsif($data_source =~ /HRRRret_WFIP2/) {
	$anal_dir =
            sprintf("RR_retro/$data_source/%4d%2.2d%2.2d%2.2d/postprd/conus/",
                    $year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "HRRR") {
	$anal_dir =
	    sprintf("/whome/rtrr/hrrr/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "HRRRv4_NCEP") {
	$anal_dir =
	    sprintf("/whome/rtrr/hrrrv4_ncepfcst/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "HRRRv4_NCEP_iso") {
	$anal_dir =
	    sprintf("/whome/rtrr/hrrrv4_ncepfcst/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "HRRR_AKv4_NCEP") {
        $anal_dir =
            sprintf("/lfs1/BMC/nrtrr/HRRRv4_AK_NCEPfcst/run/%4d%2.2d%2.2d%2.2d/postprd",
                    $year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "HRRR_AKv4_NCEP_iso") {
        $anal_dir =
            sprintf("/lfs1/BMC/nrtrr/HRRRv4_AK_NCEPfcst/run/%4d%2.2d%2.2d%2.2d/postprd",
                    $year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "RRFS_dev2") {
#	$anal_dir =
#	    sprintf("/lfs4/BMC/nrtrr/RRFS/conus_dev2/run/%4d%2.2d%2.2d%2.2d/postprd",
#		    $year+1900,$month+1,$mday,$hour);
#        $template = sprintf("RRFS_CONUS.t%02dz.bgrd3d%02d.tm%02d",$hour,$desired_fcst_len,$hour);
        $anal_dir =
            sprintf("/home/rtrr/rrfs/ptmp/com/RRFS_CONUS/para/RRFS_dev2.%04d%02d%02d/%02d",
                    $year+1900,$month+1,$mday,$hour);
        #$template = sprintf("RRFS_CONUS.t%02dz.bgrd3df%03d.tm%02d.grib2",$hour,$desired_fcst_len,$hour);
        $template = sprintf("RRFS_CONUS.t%02dz.bgrd3df%03d.tm00.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "RRFS_dev2_iso") {
#	$anal_dir =
#	    sprintf("/lfs4/BMC/nrtrr/RRFS/conus_dev2/run/%4d%2.2d%2.2d%2.2d/postprd",
#		    $year+1900,$month+1,$mday,$hour);
#        $template = sprintf("RRFS_CONUS.t%02dz.bgdawp%02d.tm%02d",$hour,$desired_fcst_len,$hour);
        $anal_dir =
            sprintf("/home/rtrr/rrfs/ptmp/com/RRFS_CONUS/para/RRFS_dev2.%04d%02d%02d/%02d",
                    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("RRFS_CONUS.t%02dz.bgdawpf%03d.tm00.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "RTMA_dev1") {
        $anal_dir =
            sprintf("/lfs4/BMC/nrtrr/NCO_dirs/ptmp/com/RTMA/para/RTMA_dev1.%04d%02d%02d/%02d",
                    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("RTMA.t%02dz.bgrd3df%03d.tm00.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "RTMA_dev1_iso") {
        $anal_dir =
            sprintf("/lfs4/BMC/nrtrr/NCO_dirs/ptmp/com/RTMA/para/RTMA_dev1.%04d%02d%02d/%02d",
                    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("RTMA.t%02dz.bgdawpf%03d.tm00.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "RRFS_dev1") {
	$anal_dir =
	    sprintf("/home/rtrr/rrfs/ptmp/com/RRFS_CONUS/para/RRFS_dev1.%04d%02d%02d/%02d",
		    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("RRFS_CONUS.t%02dz.bgrd3df%03d.tm00.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "RRFS_dev1_windtest") {
	$anal_dir =
	    sprintf("/lfs4/BMC/nrtrr/RRFS/conus_dev1/run/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("RRFS_CONUS.t%02dz.bgrd3d%02d.tm00",$hour,$desired_fcst_len);
    } elsif($data_source eq "RRFS_dev1_iso") {
	$anal_dir =
	    sprintf("/home/rtrr/rrfs/ptmp/com/RRFS_CONUS/para/RRFS_dev1.%04d%02d%02d/%02d",
		    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("RRFS_CONUS.t%02dz.bgdawpf%03d.tm00.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "RRFS_NA_13km_dev1") {
        $anal_dir =
            sprintf("/lfs4/BMC/nrtrr/NCO_dirs/stmp/tmpnwprd/RRFS_NA_13km_dev1/%04d%02d%02d%02d/postprd",
                    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("RRFS_NA_13km.t%02dz.bgrd3df%03d.tm00.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "RRFS_NA_13km_dev1_iso") {
        $anal_dir =
            sprintf("/lfs4/BMC/nrtrr/NCO_dirs/stmp/tmpnwprd/RRFS_NA_13km_dev1/%04d%02d%02d%02d/postprd",
                    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("RRFS_NA_13km.t%02dz.bgdawpf%03d.tm00.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "RRFS_NA_3km_dev1") {
        $anal_dir =
            sprintf("/lfs4/BMC/nrtrr/NCO_dirs/stmp/tmpnwprd/RRFS_NA_3km_dev1/%04d%02d%02d%02d/postprd",
                    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("RRFS_NA_3km.t%02dz.bgrd3df%03d.tm00.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "RRFS_NA_3km_dev1_iso") {
        $anal_dir =
            sprintf("/lfs4/BMC/nrtrr/NCO_dirs/stmp/tmpnwprd/RRFS_NA_3km_dev1/%04d%02d%02d%02d/postprd",
                    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("RRFS_NA_3km.t%02dz.bgdawpf%03d.tm00.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "RRFS_NA_3km_dev1_HRRR_iso") {
        $anal_dir =
            sprintf("/lfs4/BMC/nrtrr/NCO_dirs/stmp/tmpnwprd/RRFS_NA_3km_dev1/%04d%02d%02d%02d/postprd/hrrr_grid",
                    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("RRFS_NA_3km.t%02dz.bgdawpf%03d.tm00.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "RRFS_NA_3km_dev1_AK_iso") {
        $anal_dir =
            sprintf("/lfs4/BMC/nrtrr/NCO_dirs/stmp/tmpnwprd/RRFS_NA_3km_dev1/%04d%02d%02d%02d/postprd/hrrrak_grid",
                    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("RRFS_NA_3km.t%02dz.bgdawpf%03d.tm00.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "RRFS_dev3") {
	$anal_dir =
            sprintf("/home/rtrr/rrfs/ptmp/com/RRFS_CONUS/para/RRFS_dev3.%04d%02d%02d/%02d",
                    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("RRFS_CONUS.t%02dz.bgrd3df%03d.tm00.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "RRFS_dev3_iso") {
	$anal_dir =
            sprintf("/home/rtrr/rrfs/ptmp/com/RRFS_CONUS/para/RRFS_dev3.%04d%02d%02d/%02d",
                    $year+1900,$month+1,$mday,$hour);
	$template = sprintf("RRFS_CONUS.t%02dz.bgdawpf%03d.tm00.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "RRFS_dev4") {
	$anal_dir =
            sprintf("/home/rtrr/rrfs/ptmp/com/RRFS_CONUS/para/RRFS_dev4.%04d%02d%02d/%02d",
                    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("RRFS_CONUS.t%02dz.bgrd3df%03d.tm00.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "RRFS_dev4_iso") {
	$anal_dir =
            sprintf("/home/rtrr/rrfs/ptmp/com/RRFS_CONUS/para/RRFS_dev4.%04d%02d%02d/%02d",
                    $year+1900,$month+1,$mday,$hour);
	$template = sprintf("RRFS_CONUS.t%02dz.bgdawpf%03d.tm00.grib2",$hour,$desired_fcst_len);
    } elsif($data_source eq "RTMA_3D_GSD") {
	$anal_dir =
	    sprintf("/whome/rtrr/rtma_3d/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "RTMA_3D_GSD_dev1") {
	$anal_dir =
	    sprintf("/whome/rtrr/rtma_3d_dev1/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "RTMA_3D_AK") {
	$anal_dir =
	    sprintf("/whome/rtrr/rtma_3d_ak/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "RTMA_3D_RU_EMC") {
	$anal_dir =
	    sprintf("/public/data/grids/rtma_3d/conus/wrfsubhnat/grib2");
    } elsif($data_source eq "RTMA_3D_BEC") {
	$anal_dir =
	    sprintf("/public/data/grids/rtma_3d_bec/conus/wrfsubhnat/grib2");
    } elsif($data_source eq "RTMA_3D_BEC_iso") {
	$anal_dir =
	    sprintf("/public/data/grids/rtma_3d_bec/conus/wrfsubhprs/grib2");
    } elsif($data_source eq "RTMA_3D_RU_GSD") {
	$anal_dir =
	    sprintf("/home/rtrr/rtma_3d_ru/%4d%2.2d%2.2d%2.2d00/postprd",
		    $year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "HRRR_dev3") {
	$anal_dir =
	    sprintf("/home/rtrr/hrrr_dev3/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("wrfnat_hrconus_%02d.grib2",$desired_fcst_len);
    } elsif($data_source eq "HRRR_dev3_iso") {
	$anal_dir =
	    sprintf("/home/rtrr/hrrr_dev3/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("wrfprs_hrconus_%02d.grib2",$desired_fcst_len);
    } elsif($data_source eq "HRRRDAS") {
	$anal_dir =
	    sprintf("/lfs1/BMC/wrfruc/HRRRE/cycle/%4d%2.2d%2.2d%2.2d/postprd_mem0000",
		    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("wrfnat_conus_mem0000_%02d.grib2",$desired_fcst_len);
    } elsif($data_source eq "HRRRDAS_iso") {
	$anal_dir =
	    sprintf("/lfs1/BMC/wrfruc/HRRRE/cycle/%4d%2.2d%2.2d%2.2d/postprd_mem0000",
		    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("wrfprs_conus_mem0000_%02d.grib2",$desired_fcst_len);
    } elsif($data_source eq "HRRRE_mem0") {
	$anal_dir =
	    sprintf("/lfs4/BMC/wrfruc/HRRRE/forecast/%4d%2.2d%2.2d%2.2d/postprd_mem0000",
		    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("wrfnat_mem0000_%02d.grib2",$desired_fcst_len);
    } elsif($data_source eq "HRRRE_mem1") {
	$anal_dir =
	    sprintf("/lfs4/BMC/wrfruc/HRRRE/forecast/%4d%2.2d%2.2d%2.2d/postprd_mem0001",
		    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("wrfnat_mem0001_%02d.grib2",$desired_fcst_len);
    } elsif($data_source eq "HRRRE_mem2") {
	$anal_dir =
	    sprintf("/lfs4/BMC/wrfruc/HRRRE/forecast/%4d%2.2d%2.2d%2.2d/postprd_mem0002",
		    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("wrfnat_mem0002_%02d.grib2",$desired_fcst_len);
    } elsif($data_source eq "HRRRE_mem3") {
	$anal_dir =
	    sprintf("/lfs4/BMC/wrfruc/HRRRE/forecast/%4d%2.2d%2.2d%2.2d/postprd_mem0003",
		    $year+1900,$month+1,$mday,$hour);
        $template = sprintf("wrfnat_mem0003_%02d.grib2",$desired_fcst_len);
    } elsif($data_source eq "HRRR_AK" || $data_source eq "HRRR_AK_iso") {
	$anal_dir =
	    sprintf("/whome/rtrr/hrrr_ak/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "HRRR_AK_dev" || $data_source eq "HRRR_AK_dev_iso") {
	$anal_dir =
	    sprintf("/lfs1/BMC/wrfruc/HRRR_AK_dev/run/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "HRRR_HI" || $data_source eq "HRRR_HI_iso") {
	$anal_dir =
	    sprintf("/whome/rtrr/hrrr_hi/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "HRRR_NEST_PLAINS" || $data_source eq "HRRR_NEST_PLAINS_iso") {
	$anal_dir =
	    sprintf("/whome/rtrr/hrrr_nest2/%4d%2.2d%2.2d%2.2d/postprd",
		    $year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "NAM_NEST_AK") {
	$anal_dir =
	    sprintf("/public/data/grids/nam/aknest/grib2");
    } elsif($data_source eq "NAM_NEST_HI") {
	$anal_dir =
	    sprintf("/public/data/grids/nam/hawaiinest/grib2");
    } elsif($data_source eq "HRRRv2_NCO") {
	$anal_dir =
	    sprintf("/public/data/grids/hrrrv2/conus/wrfnat/grib2");
    } elsif($data_source eq "HRRR_WFIP2") {
        $anal_dir =
            sprintf("/mnt/lfs1/BMC/nrtrr/HRRR_WFIP2/run/%4d%2.2d%2.2d%2.2d/postprd/conus",
                    $year+1900,$month+1,$mday,$hour);
    } elsif($data_source eq "HRRR_NREL") {
        $anal_dir =
	    sprintf("/public/data/gsd/hrrr_nrel/conus/wrfnat");
    } elsif($data_source eq "HRRR_OPS") {
	$anal_dir =
	    sprintf("/public/data/grids/hrrr/conus/wrfnat/grib2/");
    } elsif($data_source eq "HRRR_OPS_iso") {
	$anal_dir =
	    sprintf("/public/data/grids/hrrr/conus/wrfprs/grib2/");
    } elsif($data_source eq "HRRR_OPS_AK_iso") {
	$anal_dir =
	    sprintf("public/data/grids/hrrrak/alaska/wrfprs/grib2/");
    } elsif($data_source eq "HRRR_AKv4_EMC_iso") {
	$anal_dir =
	    sprintf("/public/data/grids/hrrrv4/alaska/wrfprs/grib2/");
    } elsif($data_source eq "HRRR_AKv4_EMC") {
	$anal_dir =
	    sprintf("/public/data/grids/hrrrv4/alaska/wrfnat/grib2/");
    } elsif($data_source eq "HRRR_AK_OPS_iso") {
	$anal_dir =
	    sprintf("/public/data/grids/hrrrak/alaska/wrfprs/grib2/");
    } elsif($data_source eq "HRRR_AK_OPS") {
	$anal_dir =
	    sprintf("/public/data/grids/hrrrak/alaska/wrfnat/grib2/");
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
	$anal_dir = "/public/data/grids/rap/awip32/grib2";
    } elsif($data_source eq "RRrapx252") {
	$anal_dir = "/public/data/grids/rap/hyb_A252/grib2";
    } elsif($data_source eq "isoRRrapx") {
	$anal_dir = "/public/data/grids/rap/iso_130/grib2";
    } elsif($data_source eq "rt_gfsv16_gf" ) { 
        $anal_dir =
            sprintf("/lfs4/BMC/gsd-fv3-dev/rtruns/GFSv16_HFIP/FV3GFSrun/rt_gfsv16_gf/gfs.%4d%2.2d%2.2d/%2.2d/atmos",
                $year+1900,$month+1,$mday,$hour);
        $template = sprintf("gfs.t%02dz.pgrb2.0p25.f%03d",$hour,$desired_fcst_len);
    } elsif($data_source eq "rt_gfsv16_mynn" ) { 
        $anal_dir =
            sprintf("/lfs4/BMC/gsd-fv3-dev/rtruns/GFSv16_HFIP/FV3GFSrun/rt_gfsv16_mynn/gfs.%4d%2.2d%2.2d/%2.2d/atmos",
                $year+1900,$month+1,$mday,$hour);
        $template = sprintf("gfs.t%02dz.pgrb2.0p25.f%03d",$hour,$desired_fcst_len);
    } elsif($data_source eq "rt_gfsv16_thmp_subcyc" ) { 
        $anal_dir =
            sprintf("/lfs4/BMC/gsd-fv3-dev/rtruns/GFSv16_HFIP/FV3GFSrun/rt_gfsv16_thmp_subcyc/gfs.%4d%2.2d%2.2d/%2.2d/atmos",
                $year+1900,$month+1,$mday,$hour);
        $template = sprintf("gfs.t%02dz.pgrb2.0p25.f%03d",$hour,$desired_fcst_len);
    } elsif($data_source eq "rt_ccpp_gsd_L128" ) { 
        $anal_dir =
            sprintf("/lfs4/BMC/gsd-fv3-dev/rtruns/UFS-CAMsuite/FV3GFSrun/rt_ufscam_l127/gfs.%4d%2.2d%2.2d/%2.2d/atmos",
                $year+1900,$month+1,$mday,$hour);
        $template = sprintf("gfs.t%02dz.pgrb2.0p25.f%03d",$hour,$desired_fcst_len);
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
	} elsif($data_source eq "NAM_NEST_HI") {
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
	} elsif($data_source =~ /HRRRret_WFIP2/) {
	    $template = sprintf("wrfnat_conus_%02d00.grib2",$desired_fcst_len);
	} elsif($data_source =~ /HRRRret/) {
	    $template = sprintf("wrfnat_hrconus_%02d.grib2",$desired_fcst_len);
	} elsif($data_source =~ /RRret/) {
	    $template = sprintf("wrfnat_rr_%02d.grib2",$desired_fcst_len);
	} elsif($data_source =~ /^RRFSret/) {
            if($data_source =~ /iso/) {
              $template = sprintf("RRFS_CONUS.t%02dz.bgdawp%02d.tm%02d",$hour,$desired_fcst_len,$hour);
	    } else {
              $template = sprintf("RRFS_CONUS.t%02dz.bgrd3d%02d.tm%02d",$hour,$desired_fcst_len,$hour);
            }
	} elsif($data_source eq "HRRR") {
	    $template = sprintf("wrfnat_hrconus_%02d.grib2",$desired_fcst_len);
	} elsif($data_source eq "HRRR_AK") {
	    $template = sprintf("wrfnat_hralaska_%02d.grib2",$desired_fcst_len);
	} elsif($data_source eq "HRRR_AK_iso") {
	    $template = sprintf("wrfprs_hralaska_%02d.grib2",$desired_fcst_len);
	} elsif($data_source eq "HRRR_AK_dev") {
	    $template = sprintf("wrfnat_hralaska_%02d.grib2",$desired_fcst_len);
	} elsif($data_source eq "HRRR_AK_dev_iso") {
	    $template = sprintf("wrfprs_hralaska_%02d.grib2",$desired_fcst_len);
	} elsif($data_source eq "HRRR_AKv4_NCEP") {
	    $template = sprintf("wrfnat_hralaska_%02d.grib2",$desired_fcst_len);
	} elsif($data_source eq "HRRR_AKv4_NCEP_iso") {
	    $template = sprintf("wrfprs_hralaska_%02d.grib2",$desired_fcst_len);
	} elsif($data_source eq "HRRR_HI") {
	    $template = sprintf("wrfnat_hrhawaii_%02d.grib2",$desired_fcst_len);
	} elsif($data_source eq "HRRR_HI_iso") {
	    $template = sprintf("wrfprs_hrhawaii_%02d.grib2",$desired_fcst_len);
	} elsif($data_source eq "HRRR_NEST_PLAINS") {
	    $template = sprintf("wrfnat_hrnest2_%02d.grib2",$desired_fcst_len);
	} elsif($data_source eq "HRRR_NEST_PLAINS_iso") {
	    $template = sprintf("wrfprs_hrnest2_%02d.grib2",$desired_fcst_len);
        } elsif($data_source eq "HRRR_WFIP2") {
            $template = sprintf("wrfnat_conus_%02d00.grib2",$desired_fcst_len);
        } elsif($data_source eq "RTMA_3D_GSD") {
            $template = sprintf("wrfnat_hrconus_%02d.grib2",$desired_fcst_len);
        } elsif($data_source eq "RTMA_3D_GSD_dev1") {
            $template = sprintf("wrfnat_hrconus_%02d.grib2",$desired_fcst_len);
        } elsif($data_source eq "RTMA_3D_AK") {
            $template = sprintf("wrfnat_hrconus_%02d.grib2",$desired_fcst_len);
	} elsif($data_source eq "RTMA_3D_RU_EMC") {
	    $template = sprintf("%02d%03d%02d00%04d",
				$year%100,$yday+1,$hour,$desired_fcst_len);
	} elsif($data_source eq "RTMA_3D_BEC") {
	    $template = sprintf("%02d%03d%02d00%04d",
				$year%100,$yday+1,$hour,$desired_fcst_len);
	} elsif($data_source eq "RTMA_3D_BEC_iso") {
	    $template = sprintf("%02d%03d%02d00%04d",
				$year%100,$yday+1,$hour,$desired_fcst_len);
        } elsif($data_source eq "RTMA_3D_RU_GSD") {
            $template = sprintf("wrfnat_hrconus_%02d.grib2",$desired_fcst_len);
	} elsif($data_source eq "SAR_FV3_GSD_iso") {
	    $template = sprintf("%02d%03d%02d%04d00",
                                $year%100,$yday+1,$hour,$desired_fcst_len);
	} elsif($data_source eq "SAR_FV3_GSD") {
	    $template = sprintf("%02d%03d%02d%04d00",
                                $year%100,$yday+1,$hour,$desired_fcst_len);
	} elsif($data_source eq "HRRR_OPS") {
	    $template = sprintf("%02d%03d%02d00%04d",
				$year%100,$yday+1,$hour,$desired_fcst_len);
	} elsif($data_source eq "HRRR_OPS_iso") {
	    $template = sprintf("%02d%03d%02d00%04d",
				$year%100,$yday+1,$hour,$desired_fcst_len);
	} elsif($data_source eq "HRRR_OPS_AK_iso") {
	    $template = sprintf("%02d%03d%02d00%04d",
				$year%100,$yday+1,$hour,$desired_fcst_len);
	} elsif($data_source eq "HRRR_AKv4_EMC_iso") {
	    $template = sprintf("%02d%03d%02d00%04d",
				$year%100,$yday+1,$hour,$desired_fcst_len);
	} elsif($data_source eq "HRRR_AKv4_EMC") {
	    $template = sprintf("%02d%03d%02d00%04d",
				$year%100,$yday+1,$hour,$desired_fcst_len);
	} elsif($data_source eq "HRRR_AK_OPS_iso") {
	    $template = sprintf("%02d%03d%02d00%04d",
				$year%100,$yday+1,$hour,$desired_fcst_len);
	} elsif($data_source eq "HRRR_AK_OPS") {
	    $template = sprintf("%02d%03d%02d00%04d",
				$year%100,$yday+1,$hour,$desired_fcst_len);
	} elsif($data_source eq "HRRR_NREL") {
	    $template = sprintf("%02d%03d%02d%04d00",
				$year%100,$yday+1,$hour,$desired_fcst_len);
	} elsif($data_source eq "HRRR_iso") {
	    $template = sprintf("wrfprs_hrconus_%02d.grib2",$desired_fcst_len);
	    # dont need to worry about .al00 files for HRRR, because they don't exist.
	} elsif($data_source eq "HRRRv4_NCEP") {
	    $template = sprintf("wrfnat_hrconus_%02d.grib2",$desired_fcst_len);
	} elsif($data_source eq "HRRRv4_NCEP_iso") {
	    $template = sprintf("wrfprs_hrconus_%02d.grib2",$desired_fcst_len);
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
