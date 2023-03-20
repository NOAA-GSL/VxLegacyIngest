use strict;
my %month_num = (Jan => 1, Feb => 2, Mar => 3, Apr => 4, May => 5, Jun => 6,
		 Jul => 7, Aug => 8, Sep => 9, Oct =>10, Nov =>11, Dec =>12);
use vars(%month_num);

sub get_iso_file3 {
    my($run_time,$data_source,$DEBUG,$desired_fcst_len,$fcst_min)=@_;
    my ($out_file,$type);    

    unless(defined $desired_fcst_len) {
	die "must have a desired forecast len!\n";
    }

    my $anal_dir;
    my $filename="";
    my $base_file;
    if($data_source eq "RR1h_prs") {
	$anal_dir = "/whome/rtrr/rr/WRFDATE/postprd/";
    } elsif($data_source eq "RAP_OPS") {
        $anal_dir = "/pan2/projects/public/data/grids/rap/iso_130/grib2/";
    } elsif($data_source eq "HRRR_AK") {
	$anal_dir = "/whome/rtrr/hrrr_ak/WRFDATE/postprd/";
    } elsif($data_source eq "HRRR_HI") {
	$anal_dir = "/whome/rtrr/hrrr_hi/WRFDATE/postprd/";
    } elsif($data_source eq "HRRR") {
	$anal_dir = "/whome/rtrr/hrrr/WRFDATE/postprd/";
    } elsif($data_source eq "HRRR_OPS") {
	$anal_dir = "/public/data/grids/hrrr/conus/wrfsubh/grib2/";
    } elsif($data_source eq "RTMAv2_6_EMC") {
	$anal_dir = "/pan2/projects/public/data/grids/rtma/2p5km_ru/grib2/";
    } elsif($data_source eq "RTMA_GSD") {
	$anal_dir = "/whome/rtrr/rtma_15min/RTMADATE/";
    } elsif($data_source eq "RTMA_GSD_dev1") {
	$anal_dir = "/whome/rtrr/rtma_15min_dev1/RTMADATE/";
    } elsif($data_source eq "RTMAv2_6_EMC") {
	$anal_dir = "/pan2/projects/public/data/grids/rtma/2p5km_ru/grib2/";
    } elsif($data_source eq "RTMAv2_6_EMCxx") {
	$anal_dir = "/pan2/projects/public/data/grids/rtma/2p5km_ru/grib2/";
    } elsif($data_source eq "RTMAv2_6_EMCxx") {
	$anal_dir = "/pan2/projects/public/data/grids/rtma/2p5km_ru/grib2/";
    } elsif($data_source eq "HRRRv3_EMC") {
	$anal_dir = "/pan2/projects/public/data/grids/hrrrv3/conus/wrfprs/grib2/";
    } elsif($data_source eq "RAPv4_EMC") {
	$anal_dir = "/pan2/projects/public/data/grids/rapv4/full/wrfprs/grib2/";
    } elsif($data_source eq "RAPv4_EMC_130") {
	$anal_dir = "/pan2/projects/public/data/grids/rapv4/iso_130/grib2/";
    } elsif($data_source eq "HRRR_OPS") {
        $anal_dir = "/pan2/projects/public/data/grids/hrrr/conus/wrfnat/grib2/";
    } elsif($data_source eq "RTMA_v2_7_RU_EMC") {
        $anal_dir = "/public/data/grids/rtma_v2.7.0/2p5km_ru/grib2/";
    } elsif($data_source eq "RTMA_3D_RU_EMC") {
        $anal_dir = "/public/data/grids/rtma_3d/conus/wrfsubhprs/grib2/";
    } elsif($data_source eq "RTMA_3D_RU_GSD") {
        $anal_dir = "/home/rtrr/rtma_3d_ru/RTMADATE/postprd/";
    } elsif($data_source eq "RTMA_RU_OPS") {
        $anal_dir = "/public/data/grids/rtma/2p5km_ru/grib2/";
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
       $anal_dir =~ m|rtfim/FIM/|) {
	$suffix = "";
    } elsif ($anal_dir =~ m|/rt1/rtruc/13km/run/maps_fcst|) {
	# have .grib and .grib2 in this directory
	# .grib2 is faster, so use it.
	$suffix = ".grib2";
    }

    my ($secs,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)
	= gmtime($run_time);
    if($anal_dir =~ /WRFDATE/ || $anal_dir =~ /retro/) {
	# if we're not on an hour, don't match WRFDATE
	if($min == 0) {
	    # replace with the date format used by WRF (FIM and RR)
	    my $fim_date = sprintf("%04d%02d%02d%02d",
				   $year+1900,$mon+1,$mday,$hour);
	    if($anal_dir =~ s/WRFDATE/$fim_date/) {
		my $base_file = sprintf("wrftwo_subh_hrconus_%02d.grib2",$desired_fcst_len);
		$filename = "${anal_dir}$base_file";
	    } else {
		$anal_dir .= "/$fim_date/postprd/";
	    }
	}
    } elsif($data_source =~ /^RTMA_3D_RU_GSD/) {
        # replace with the date format used by RTMA
        my $rtma_date = sprintf("%04d%02d%02d%02d%02d",
                               $year+1900,$mon+1,$mday,$hour,$min);
        if($anal_dir =~ s/RTMADATE/$rtma_date/) {
            my $base_file = sprintf("wrftwo_hrconus_%02d.grib2",$desired_fcst_len);
            $filename = "${anal_dir}$base_file";
        } else {
            die "wrong directory!\n";
        }

    } elsif($anal_dir =~ /RTMADATE/) {
	# replace with the date format used by RTMA
	my $rtma_date = sprintf("%04d%02d%02d%02d%02d",
			       $year+1900,$mon+1,$mday,$hour,$min);
	if($anal_dir =~ s/RTMADATE/$rtma_date/) {
	    my $base_file = sprintf("wrftwo_hrconus_rtma.grib2");
	    $filename = "${anal_dir}$base_file";
	} else {
	    die "wrong directory!\n";
	}
	
    } elsif($data_source =~ /^RTMA_3D_RU_EMC/) {
        $base_file = sprintf("%02d%03d%02d%02d%02d%02d",
                             $year%100,$yday+1,$hour,$min,$desired_fcst_len,$fcst_min);
        $filename = "${anal_dir}$base_file";

    } elsif($data_source eq "HRRR_OPS" || $data_source =~ /^RTMA/) {
	# files on public
	# for HRRR_OPS on public, we need to undo the increment of the desired_fcst_len done in ceil_driver.pl
	if($fcst_min > 0) {
	    $desired_fcst_len--;
	}
	$base_file = sprintf("%02d%03d%02d%02d%04d%02d",
			     $year%100,$yday+1,$hour,$min,$desired_fcst_len,$fcst_min);
	$filename = "${anal_dir}$base_file";
	
    } else {
      $filename = "";
    }
    if($DEBUG) {
	print "NOW filename is $filename\n";
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
