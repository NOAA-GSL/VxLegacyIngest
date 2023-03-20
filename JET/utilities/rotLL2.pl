#!/usr/bin/perl

#DIDN'T GET THIS TO WORK. USE rotLL.pl instead.
use POSIX;
my $PI = acos(-1);
my $dtr = $PI/180.;

my @lats = (-34.478735722767);
my @lons = (-46.1137802257097);
for($i=0;$i<@lats;$i++) {
    my $latin = $lats[$i];
    my $lonin = $lons[$i];

    # from NCL graphics ncl_ncarg-5.2.1/ni/src/ncl/GetGrids.c routine rot2ll
    my $latpol = 42.5;
    my $lonpol = 76.;

    #  convert to xyz coordinates
    my $x = cos($latin * $dtr) * cos($lonin * $dtr);
    my $y = cos($latin * $dtr) * sin($lonin * $dtr);
    my $z = sin($latin * $dtr);

    # rotate around y axis */
    my $rotang = - ($latpole + 90) * $dtr;
    my $sinrot = sin($rotang);
    my $cosrot = cos($rotang);
    my $ry = $y;
    my $rx = $x * $cosrot + $z * $sinrot;
    my $rz = -$x * $sinrot + $z * $cosrot;
    
    # convert back to lat/lon */
	
    my $tlat = asin($rz) / $dtr;
    my $tlon;
    if (fabs($rx) > 0.0001) {
	$tlon = atan2($ry,$rx) / $dtr;
    }
    elsif ($ry > 0) {
	$tlon = 90.0;
    }
    else {
	$tlon = -90.0;
    }
    # remove the longitude rotation */
	
    $tlon = $tlon + $lonpole;
    if ($tlon < -180) {
	$tlon = $tlon + 360.0;
    }
    if ($tlon > 180) {
	$tlon = $tlon - 360.0;
    }
    print "rotated: $latin/$lonin, geographic: $tlat/$tlon\n";
}
