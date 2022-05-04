sub get_grid {
    use POSIX qw(strftime);
    my($file,$thisDir,$DEBUG) = @_;
    use Time::Local
    #require "timelocal.pl";   #includes 'timegm' for calculations in gmt
    require "jy2mdy.pl";
    # get proper path for appropriate version of wgrib2
    # so do it with this terrible hack:
#    my $wgrib2 = "/apps/wgrib2/0.1.9.5.1/wgrib2"; #ZEUS 
    my $wgrib2 = "/apps/wgrib2/0.1.9.6a/bin/wgrib2"; # JET
    my $ncl_filedump = "ncl_filedump"; # use the system path on both ZEUS and jet
    my($year,$julday,$hour,$fcst_proj);

    my($alat1,$elon1,$elonv,$alattan,$nx,$ny,$dx,$grib_type,$grid_type,
       $run_date,$fcst_proj,$wind_rot_flag);
    $grid_type = 0; #unknown
    $grib_type = 0;
    # first, let's see if its grib(1)
#    $unsafe_arg = qq{$thisDir/col_wgrib.x -V $file};
#    $unsafe_arg = qq{/apps/wgrib/1.8.1.0b/wgrib -V $file}; # ZEUS
     $unsafe_arg = qq{/apps/wgrib/1.8.1.0b/bin/wgrib -V $file}; # JET
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
       } elsif(/date (\d+) .* (\d+)min fcst/) {
	   $run_date=$1;
	   $fcst_proj=$2/60;
	   print "DATE IS $run_date $fcst_proj\n";
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
	} elsif(/timerange .* nx (\d*) ny (\d*)/) {
	    $nx = $1;
	    $ny = $2;
	    if($nx == 758 && $ny == 567) {
		$grib_type = 1;
		$grid_type = 20; # define '20' as OLD rotated lat/lon grid for RR
		last;
	    }
            elsif($nx == 953 && $ny == 834) {
		$grib_type = 1;
		$grid_type = 21; # define '21' as NEW rotated lat/lon grid for RR
		last;
	    }
	}
    }
    close INVENTORY;
    if($grib_type != 1) {
	# its not grib(1). May be grib2
	#$unsafe_arg = qq{$wgrib2 -set center 7 -grid $file}; # attempt to get around bad UPP output. Didn't work JAH 20161114
	$unsafe_arg = qq{$wgrib2 -grid $file};
	$unsafe_arg =~ /([\=-\w. \/]+)/;
	$arg = $1;
	if($DEBUG) {
	    print "NUMBER 2 arg is $arg\n";
	}
	open(INVENTORY,"$arg 2> /dev/null |") ||
	    print "problem with |$arg|: $!";
	$_ = <INVENTORY>;
	print;

        if(/:winds\(grid\):$/){
            $wind_rot_flag = 0;
            print "Grid relative winds\n";
        } else {
            $wind_rot_flag = 1;
            print "Earth relative winds\n";
        }

     	$_ = <INVENTORY>;
	print;

	if(/Lambert Conformal:/) {

	    $grib_type = 2;
	    $_ = <INVENTORY>;
	    #print;
	    /Lat1 ([\-\.\d]+) Lon1 ([\-\.\d]+) Lov ([\-\.\d]+)/i;
	    $la1 = $1;			# lat1
	    $lo1 = $2;			# lat2
	    $lov = $3;
	    print "la1 |$la1|, lo1 $lo1\n";
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
	    # a hack, because the '-grid' option USED TO NOT work on jet
	    if($dx == 0) {
		if($nx == 349 && $ny == 277) {
		    # AWIPS 221 grid
		    $dx = 32463.00;
		} else {
		    # all other grib2 grids
		    $dx = 13545.00;
		}
		$dy = $dx;
	    }
	    #print "dx |$dx|, dy |$dy|\n";
	    if($dx == $dy) {
		$grid_type = 1;	# 1 = Lamb. Conf with 1 std parallel
	    } else {
		$grid_type = 0;	# unknown grid type
	    }
        }elsif(/Mercator grid:/) { # added 20170516 - JAH
            $grib_type = 2;
            $grid_type = 5;
            $lov = 0.0; # !!!!! Not needed for Mercator, but some code expects it
            /Mercator grid: \((\d+) x (\d+)\) LatD ([\-\.\d]+) /i;
            $nx = $1;
            $ny = $2;
            $latin1 = $3;
            print "nx= $nx ny= $ny $_\n";
            $_ = <INVENTORY>; # reading next line
            /lat ([\-\.\d]+) to ([\-\.\d]+) by ([\-\.\d]+) m/i;
            $la1 = $1;
            my $la2 = $2;
            $dy = $3;
            $_ = <INVENTORY>; # reading next line
            /lon ([\-\.\d]+) to ([\-\.\d]+) by ([\-\.\d]+) m/i;
            $lo1 = $1;
            my $lo2 = $2;
            $dx = $3;
            if($dx == 0) {
              $dx = 3000.0; # !!!!! HARD CODED TO HRRR!!!!! This is due to wgrib2/UPP limitations
              $dy = 3000.0; # !!!!! HARD CODED TO HRRR!!!!! This is due to wgrib2/UPP limitations
            }
            print "MERCATOR\n";
            print "lat1 = $la1, lon1 = $lo1, alatin = $latin1\n";
        }elsif(/polar stereographic grid:/) { 

            $grib_type = 2;
            $grid_type = 3;
#           $_ = <INVENTORY>;
            #print;
#           /lat1 ([\-\.\d]+) lon1 ([\-\.\d]+) Lov ([\-\.\d]+)/i;
            /polar stereographic grid: \((\d+) x (\d+)\) /i;
            $nx = $1;
            $ny = $2;
            print "nx= $nx ny= $ny $_\n";

            $_ = <INVENTORY>; # reading next line

#           /North pole Lat1 ([\-\.\d]+) Lon1 ([\-\.\d]+) LatD ([\-\.\d]+) LonV ([\-\.\d]+) /i;
            /North pole Lat1 ([\-\.\d]+) Lon1 ([\-\.\d]+) LatD ([\-\.\d]+) LonV ([\-\.\d]+) Dx ([\.\d]+) (.) Dy ([\.\d]+)/i;

#           /North pole lat1 ([\-\.\d]+) lon1 ([\-\.\d]+) latD ([\-\.\d]+) LonV ([\-\.\d]+) dx ([\-\.\d]+) dy ([\-\.\d]+)/i;
            $la1 = $1;                  # lat1
            $lo1 = $2;                  # lat2
            $latD = $3;                 # lat2
            $lov = $4;
            $dx = $5;
            my $mkm = $6;       # "m" or (maybe) "km"
            $dy = $7;

            print "la1=$la1, lo1=$lo1, latD=$latD,lonv=$lov dx=$dx dy=$dy  $_\n";

            $_ = <INVENTORY>;
            /Latin1 ([\.\d]+)/;
            $latin1 = $1;
            $_ = <INVENTORY>;
            $_ = <INVENTORY>;
            #print;  
        } elsif(/rotated lat-lon grid:\((\d+) x (\d+)/) {
            $grib_type = 2;
            $nx = $1;
            $ny = $2;
           if($nx == 956 && $ny == 831) {
                $grib_type = 2;
                $grid_type = 22; # define '22' as NEW rotated lat/lon grid for RRFS_NA_13km
            }
            elsif($nx == 4081 && $ny == 2641) {
                $grib_type = 2;
                $grid_type = 23; # define '23' as NEW rotated lat/lon grid for RRFS_NA_3km
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
	} elsif(/Arakawa/) {
	    # new wgrib2 gives us enough info to distinguish the grid type
	    $_ = <INVENTORY>;
	    print;
	    if(/rotated/) {
		$_ = <INVENTORY>;
		print;
		$_ = <INVENTORY>;
		print;
		if(/\((\d+) x (\d+)\)/) {
		    $nx = $1;
		    $ny = $2;
		    if($nx == 758 && $ny == 567) {
			$grib_type = 2;
			$grid_type = 20; # define '20' as OLD rotated lat/lon grid for RR
		    } elsif($nx == 953 && $ny == 834) {
			$grib_type = 2;
			$grid_type = 21; # define '21' as NEW rotated lat/lon grid for RR
		    }		    
		}
	    } 
	} else {
	    $grib_type = 2;
	    $grid_type = 0;
	}

	close INVENTORY;
	print "grib_type $grib_type grid_type $grid_type\n";
	# get run date
	$unsafe_arg = qq{$wgrib2 $file};
	$unsafe_arg =~ /([\=-\w. \/]+)/;
	$arg = $1;
	print "NUMBER 3 arg is |$arg|\n";
	open(DATE,"$arg 2> /dev/null|") ||
	    print "problem with |$arg|: $!";
	my $line = <DATE>;
	print "$line\n";
	($run_date) = $line =~ /d=(\d*)/;
	($fcst_proj) = $line =~ /(\d*) hour fcst/;
	$fcst_proj += 0;
	print "DATE for grib2 is $run_date, $fcst_proj\n";
	close DATE;
    }

        print "grid_type arg is |$grid_type|\n";
    if($grid_type == 0) {
        # may be a grib2 rotLL grid. This can't currently be read by wgrib2,
        # but can be read by ncl_filedump
        print "inside grib2 rotated lat-lon\n";
        $unsafe_arg = qq{$ncl_filedump $file};
        $unsafe_arg =~ /([\=-\w. \/]+)/;
        $arg = $1;
        print "NUMBER 4 arg is |$arg|\n";
        open(TRY,"$arg 2> /dev/null|") ||
            print "problem with |$arg|: $!\n";
        my $corner = undef;
        while(<TRY>) {
            #print;
            if(/corners .*\((.*),/) {
                $corner = $1 + 0; # make it a number
                print "corner is $corner\n";
                last;
            }
        }

	    print "grib_type $grib_type grid_type $grid_type\n";
            print "corner $corner\n";
        if(defined $corner) {
            # don't know whether lat or lon of SW corner will come first, and we only look at the first
#           if($corner == -10.591 || # lat
           if($corner == -10.5906 ||  $corner == -10.591 || # lat
              $corner == -139.086) { # lon
               $grid_type = 21;
# this change is made to accommodate RAP grids change on 4-28-12z 2016  
	       $unsafe_arg = qq{$wgrib2 -grid $file};
	       #$unsafe_arg = qq{$wgrib2 -set center 7 -grid $file};
               $unsafe_arg =~ /([\=-\w. \/]+)/;
               $arg = $1;
               print "NUMBER 7 arg is |$arg|\n";

              open(INVENTORY,"$arg 7> /dev/null |") ||
                 print "problem with |$arg|: $!";
	         print "int1\n";
	       $_ = <INVENTORY>;
	       print;
	       $_ = <INVENTORY>;
	       print;
	       $_ = <INVENTORY>;
	       print;
	       $_ = <INVENTORY>;
	       print;
	       $_ = <INVENTORY>;
	       print;

               /\((\d+) x (\d+)\)/;
              $nx = $1;
              $ny = $2;

              print "nx=$nx, ny=$ny\n";
	       if($nx == 953 && $ny == 834) {
		   $grid_type = 21;
		   $grib_type = 2;
	       }
# end of change 04282016






           } elsif($corner == 2.228 || # lat
                   $corner == -140.481) { # lon
               $grid_type = 20;
           }
        }else{
	    $unsafe_arg = qq{$wgrib2 -grid $file};
        $unsafe_arg =~ /([\=-\w. \/]+)/;
        $arg = $1;
        print "NUMBER 7 arg is |$arg|\n";

        open(INVENTORY,"$arg 7> /dev/null |") ||
            print "problem with |$arg|: $!";
	    print "int1\n";
	    $_ = <INVENTORY>;
	    print;
	    $_ = <INVENTORY>;
	    print;
	    $_ = <INVENTORY>;
	    print;
	    $_ = <INVENTORY>;
	    print;
	    $_ = <INVENTORY>;
	    print;

         /\((\d+) x (\d+)\)/;
          $nx = $1;
            $ny = $2;

        print "nx=$nx, ny=$ny\n";
	    if($nx == 953 && $ny == 834) {
		$grid_type = 21;
		$grib_type = 2;
	    }

   

	}
        close INVENTORY;


     print "grib type $grib_type, grid type $grid_type\n";
      }
 
     # one more try
     if($grib_type == 0) {
	# maybe its a netCDF file
	$grid_type = 1;		# ASSUME lambert conformal
	if($file =~ /stmas_ci/) {
	    # hardwire for STMAS_CI grid
	    $la1= 38.75254;
	    $lo1= -89.8269;
	    $dx= 3000;
	    $lov= -100.;
	    $latin1= 41.69 ;
	    $nx= 541;
	    $ny= 346;
	} elsif($file =~ m|hwt/lapsprd|) {
	    # hardwire for STMAS_CI grid
	    $la1= 29.23711;
	    $lo1= -105.0565;
	    $dx= 3000;
	    $lov= -98.408;
	    $latin1= 35.25;
	    $nx= 433 ;
	    $ny= 433;
	} elsif($file =~ m|laps_conus|) {
	    # hardwire for LAPS_CONUS grid
	    $la1= 21.12218;
	    $lo1= -122.7291;
	    $dx= 3000;
	    $lov= -97.5;
	    $latin1= 38.5;
	    $nx= 1799;
	    $ny= 1059;
	} elsif($file =~ m|stmas_conus|) {
	    # hardwire for STMAS_CONUS grid
	    $la1= 21.12218;
	    $lo1= -122.7291;
	    $dx= 3000;
	    $lov= -97.5;
	    $latin1= 38.5;
	    $nx= 1799;
	    $ny= 1059;
	}	    
	print "file is $file\n";
#	my($year,$julday,$hour,$fcst_proj) = $file =~m|/(..)(...)(..)00(..)00\.fsf|;
	my($year,$julday,$hour,$fcst_proj) = $file =~m|/(..)(...)(..)00(..)00\.fua|;
	$fcst_proj += 0;		# make it a number
	print "fcst len is $fcst_proj\n";
	print "year is $year, julday=$julday \n";
	my($day,$mday,$mon);
	($day,$mday,$mon_name,$year) = jy2mdy($julday,$year);
	my %mon_num =
	    (Jan=>0 ,Feb=> 1,Mar=> 2,Apr=> 3,May=> 4,
	     Jun=> 5,Jul=> 6,Aug=> 7,Sep=> 8,Oct=> 9,Nov=> 10,Dec => 11);
	$run_date = strftime("%Y%m%d%H",0,0,$hour,$mday,$mon_num{$mon_name},$year-1900);
	print "run date is $run_date\n";
    }
    # get valid_date from run_date
    my($year,$mon,$mday,$hour) = $run_date =~ /(....)(..)(..)(..)/;
    my $min=0;
    my $sec=0;
    my $valid_secs = timegm(0,0,$hour,$mday,$mon-1,$year-1900) + 3600*$fcst_proj;
    my $valid_date = sql_datetime($valid_secs);
    ($sec,$min,$hour,$maday,$mon,$year) = gmtime($valid_secs);
    if(1) {
	print "get_grid results: ".
	    "$la1,$lo1,$lov,$latin1,$nx,$ny,$dx,$grib_type,$grid_type,$valid_date,$fcst_proj,$wind_rot_flag\n";
    }
    print "get_grid results: ".
        "$la1,$lo1,$lov,$latin1,$nx,$ny,$dx,$grib_type,$grid_type,$valid_date,$fcst_proj,$wind_rot_flag\n";
    return($la1,$lo1,$lov,$latin1,$nx,$ny,$dx,$grib_type,$grid_type,$valid_date,$fcst_proj,$wind_rot_flag);
}

sub sql_datetime {
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return sprintf("%4d-%2.2d-%2.2d %2.2d:%2.2d:%2.2d",
		   $year,$mon,$mday,$hour,$min,$sec);
}
	
1;
