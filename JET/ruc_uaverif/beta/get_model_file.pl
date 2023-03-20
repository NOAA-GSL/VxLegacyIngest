my %month_num = (Jan => 1, Feb => 2, Mar => 3, Apr => 4, May => 5, Jun => 6,
		 Jul => 7, Aug => 8, Sep => 9, Oct =>10, Nov =>11, Dec =>12);
use vars(%month_num);

sub my_timeout {
    print STDERR "timeout\n";
    die 1;
}

sub get_model_file {
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
    my ($dym,$dym,$hour,$mday,$month,$year,$wday,$yday) = gmtime($run_time);
    my $jday=$yday+1;
    if($DEBUG) {
	print "|$special_type| year,month,jday,hour = $year, $month, $jday, $hour\n";
    }
    my $template = sprintf("%02d%03d%02d000%03d.grib",
			   $year%100,$jday,$hour,$desired_fcst_len);
    if($special_type eq "ini") {
	$template .= ".ini";
    }

# first look for an analysis (for ruc, anal and forecast are in same dir)
    my $anal_dir;
    if($data_source eq "Dev13") {
	$anal_dir =  "/whome/rtruc/ruc_devel/maps_fcst/";
    } elsif($data_source eq "Bak13") {
	$anal_dir = "/whome/rtruc/ruc_backup/maps_fcst/";
    } elsif($data_source eq "NoTAM13") {
	$anal_dir = "/whome/rtruc/ruc_notamdar/maps_fcst/";
    } elsif($data_source eq "dev") {
	$anal_dir = "/public/data/fsl/20kmrucx/maps_fcst/";
    } elsif($data_source =~ /MAPS/ ||
	    $data_source eq "Bak40") {
	# grib takes too long.  go back to netcdf
	$anal_dir = "/public/data/fsl/13kmruc/maps_fcst40/netcdf/";
    } elsif($data_source =~ /RUC2/ ||
	    $data_source eq "Op40") {
	# grib takes too long.  Go back to netcdf
	$anal_dir = "/public/data/grids/ruc/hyb_A236/netcdf";
    } elsif($data_source eq "Op20") {
	$anal_dir = "/public/data/grids/ruc/hyb_A252/grib/";
    } elsif($data_source eq "Bak20") {
	$anal_dir = "/public/data/fsl/13kmruc/maps_fcst20/";
    } elsif($data_source eq "Dev1320") {
	#$anal_dir = "/lfs0/projects/rtruc/13kmdev/backup/run/maps_fcst20/";
	$anal_dir = "/whome/rtruc/ruc_devel/maps_fcst20/";
    } elsif($data_source eq "isoBak13") {
	$anal_dir = "/whome/rtruc/ruc_backup/ruc_presm/";
    } elsif($data_source eq "isoOp13") {
	$anal_dir = "/public/data/grids/ruc/iso_130/grib2/";
	$template =~ s/\.grib//;
    } else {
	# use a soft link
	$anal_dir = "${data_source}_grib_dir/";
    }
    my $out_file = "$anal_dir$template";
    if ($DEBUG) {
	print "data source is $data_source.  looking\n";
	print "for $out_file\n";
    }
    my $type = 0;
    if(-r $out_file &&
       -M $out_file > 0.0014) {	# 0.0014 days =~ 2 minutes
	return ($out_file,$anal_dir,$desired_fcst_len);
    } else {
	return (undef,$anal_dir,$undef);
    }
}

1;    # return something so the require is happy
