sub get_grid {
    my($file,$thisDir,$DEBUG) = @_;
    require "timelocal.pl";   #includes 'timegm' for calculations in gmt
    my($alat1,$elon1,$elonv,$alattan,$nx,$ny,$dx,$grib_type,$grid_type,
       $run_date,$fcst_proj);
    $grib_type = 0;
    # first, let's see if its grib(1)
    $unsafe_arg = qq{$thisDir/col_wgrib.x -V $file};
    # clean it for the taint flag
    $unsafe_arg =~ /([-\w. \/\>\|\:\']+)/;
    $arg = $1;
    open(INVENTORY, "$arg 2> /dev/null |");
    while(<INVENTORY>) {
	#print;
	if(/date (\d+) .*anl/) {
	   $run_date=$1;
	   $fcst_proj=0;
	   #print "DATE IS $run_date $fcst_proj (anx)\n";
       } elsif(/date (\d+) .* (\d+)hr fcst/) {
	   $run_date=$1;
	   $fcst_proj=$2;
	   #print "DATE IS $run_date $fcst_proj\n";
	} elsif(/Lambert Conf: Lat1 ([\-\.\d]+) Lon1 ([\-\.\d]+) Lov ([\-\.\d]+)/) {
	    #print "got lambert\n";
	    $grib_type = 1;
	    $la1 = $1;
	    $lo1 = $2;
	    $lov = $3;
	    $grid_type = 1;		# Lambert conformal conic with 1 std parallel
	    $_ = <INVENTORY>;
	    #print "Got latin1\n";
	    /Latin1 ([\.\d]+)/;
	    $latin1 = $1;
	    $_ = <INVENTORY>;
	    #print "got pole\n";
	    /North Pole \((\d+) x (\d+)\) Dx ([\.\d]+)/;
	    $nx = $1;
	    $ny = $2;
	    $dx = $3 * 1000;  # send it out in meters
	    last;
	} elsif (/latlon: lat  ([\-\.\d]+) to ([\-\.\d]+) by ([\.\d]+)/) {
	    $grib_type = 1;
	    $la1 = $1;			# lat1
	    $lo1 = $2;			# lat2
	    $dx = $3 + 0;		# make sure its a number
	    $_ = <INVENTORY>;
	    #print;
	    /long ([\-\.\d]+) to ([\-\.\d]+) by ([\.\d]+), \((\d+) x (\d+)/;
	    $lov = $1;			# lon1
	    $latin1 = $2;		# lon2
	    if($latin1 < $lov) {
		$latin1 += 360;
	    }
	    my $dy = $3 + 0;		# make sure its a number
	    $nx = $4;
	    $ny = $5;
	    if($dx == $dy) {
		if($la1 < $lo1) {
		    $grid_type = 10;	# 10 = lat-lon grid, S to N
		} else {
		    $grid_type = 11;        # 11 = lat-lon grid, N to S
		}
	    } else {
		$grid_type = 0;
	    }
	    if($DEBUG) {
		print "lat: $la1 to $lo1 by $dx\n";
		print "lon: $lov to $latin1 by $dy\n";
	    }
	    last;
	}
    }
    close INVENTORY;
    if($grib_type != 1) {
	# its not grib(1). Must be grib2
	$unsafe_arg = qq{$thisDir/wgrib2.x -grid $file};
	$unsafe_arg =~ /([\=-\w. \/]+)/;
	$arg = $1;
	if($DEBUG) {
	    print "NUMBER 2 arg is $arg\n";
	}
	open(INVENTORY,"$arg 2> /dev/null |") ||
	    print "problem with |$arg|: $!";
	$_ = <INVENTORY>;
	#print;
	$_ = <INVENTORY>;
	#print;
	if(/Lambert Conformal:/) {
	    $grib_type = 2;
	    $_ = <INVENTORY>;
	    #print;
	    /Lat1 ([\-\.\d]+) Lon1 ([\-\.\d]+) Lov ([\-\.\d]+)/i;
	    $la1 = $1;			# lat1
	    $lo1 = $2;			# lat2
	    $lov = $3;
	    #print "la1 |$la1|, lo1 $lo1\n";
	    $_ = <INVENTORY>;
	    /Latin1 ([\.\d]+)/;
	    $latin1 = $1;
	    $_ = <INVENTORY>;
	    $_ = <INVENTORY>;
	    #print;
	    /North Pole \((\d+) x (\d+)\) Dx ([\.\d]+) (.) Dy ([\.\d]+) /i;
	    $nx = $1;
	    $ny = $2;
	    $dx = $3;
	    my $mkm = $4;	# "m" or (maybe) "km"
	    $dy = $5;
	    if($mkm ne "m") {
		$dx *= 1000;  # send it out in meters
	        $dy *= 1000;
	    }
	    #print "dx |$dx|, dy |$dy|\n";
	    if($dx == $dy) {
		$grid_type = 1;	# 1 = Lamb. Conf with 1 std parallel
	    } else {
		$grid_type = 0;	# unknown grid type
	    }
	} elsif(/lat-lon grid:\((\d+) x (\d+)/) {
	    $grib_type = 2;
	    $nx = $1;
	    $ny = $2;
	    $_ = <INVENTORY>;
	    /lat (.+) to (.+) by (.+)/;
	    $la1 = $1;			# lat1
	    $lo1 = $2;			# lat2
	    $dx = $3 + 0;		# make sure its a number
	    $_ = <INVENTORY>;
	    /lon (.+) to (.+) by (.+)/;
	    $lov = $1;			# lon1
	    $latin1 = $2;		# lon2
	    my $dy = $3 + 0;		# make sure its a number
	    if($dx == $dy) {
		if($la1 < $lo1) {
		    $grid_type = 10;	# 10 = lat-lon grid, S to N
		} else {
		    $grid_type = 11;        # 11 = lat-lon grid, N to S
		}
	    } else {
		$grid_type = 0;
	    }
	} else {
	    $grid_type = 0;
	}
	close INVENTORY;
	# get run date
	$unsafe_arg = qq{$thisDir/wgrib2.x $file};
	$unsafe_arg =~ /([\=-\w. \/]+)/;
	$arg = $1;
	open(DATE,"$arg 2> /dev/null |") ||
	    print "problem with |$arg|: $!";
	my $line = <DATE>;
	($run_date) = $line =~ /d=(\d*)/;
	($fcst_proj) = $line =~ /(\d*) hour fcst/;
	$fcst_proj += 0;
	#print "DATE for grib2 is $run_date, $fcst_proj\n";
	close DATE;
    }
    # get valid_date from run_date
    my($year,$mon,$mday,$hour) = $run_date =~ /(....)(..)(..)(..)/;
    my $min=0;
    my $sec=0;
    my $valid_secs = timegm(0,0,$hour,$mday,$mon-1,$year-1900) + 3600*$fcst_proj;
    ($sec,$min,$hour,$maday,$mon,$year) = gmtime($valid_secs);
    my $valid_date = sprintf("%4d%02d%02d%02d",$year+1900,$mon+1,$mday,$hour);
    #print "$la1,$lo1,$lov,$latin1,$nx,$ny,$dx,$grib_type,$grid_type,$valid_date,$fcst_proj\n";
    return($la1,$lo1,$lov,$latin1,$nx,$ny,$dx,$grib_type,$grid_type,$valid_date,$fcst_proj);
}
	
1;
