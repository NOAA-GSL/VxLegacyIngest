#!/usr/bin/perl

use strict;
use POSIX;
my $PI = acos(-1);
my $D2R = $PI/180.;

my @lats = (2.227524, 53.49178, 53.49176, 2.227517,5.211449,33.59401,47.5,40,50,53.9);
my @lons = (-140.4815, 162.9838, -10.98379, -67.51849,-140.0393,-130.1077,-104.0,-105,-60,-122.8);

my $lat_0_deg = 47.5;
my $lon_0_deg = -104.;
my $lat_g_SW_deg = 2.227524;
my $lon_g_SW_deg = -140.4815;
my $dxy_km = 13.54508;

for(my $i1=0;$i1<@lats;$i1++) {
    my ($lat_r_deg,$lon_r_deg) = rotLL_geo_to_rot($lats[$i1],$lons[$i1],$lat_0_deg,$lon_0_deg);
    my ($echo_lat_g_deg, $echo_lon_g_deg) =
	rotLL_rot_to_geo($lat_r_deg,$lon_r_deg,$lat_0_deg,$lon_0_deg);
    my($i,$j) = rotLL_geo_to_ij($lats[$i1],$lons[$i1],$lat_0_deg,$lon_0_deg,
				$lat_g_SW_deg,$lon_g_SW_deg,$dxy_km);
    my $alpha = rotLL_wind2true_deg($lats[$i1],$lons[$i1],$lat_0_deg,$lon_0_deg);
    printf("input $lats[$i1]/$lons[$i1], rotated: $lat_r_deg/$lon_r_deg, echoed $echo_lat_g_deg/$echo_lon_g_deg".
	   " i/j (1 based) %.2f/%.2f, %.2f\n",$i,$j,$alpha);
}
# find angle to rotate wind FROM rotLL coordinates TO true
# adapted from
# http://www.nco.ncep.noaa.gov/pmb/codes/nwprod/sorc/nam_wrfsi.fd/src/grid/gen_egrid_latlon.f_pre_precision
# returns alpha (in deg) so that wd_rotLL + alpha = wd_true
sub rotLL_wind2true_deg {
    my($lat_deg,$lon_deg,$lat_0_deg,$lon_0_deg) = @_;
    use POSIX;
    my $PI = acos(-1);
    my $D2R = $PI/180.;

    # deal with origin of rotLL system
    #if($lon_0_deg < 0) {$lon_0_deg += 360;} # not needed, at least in perl
    my $lon_0 = $lon_0_deg * $D2R;
    my $lat_0 = $lat_0_deg * $D2R;
    my $sphi0 = sin($lat_0);
    my $cphi0 = cos($lat_0);

    # deal with input lat/lon
    my $tlat = $lat_deg * $D2R;
    my $tlon = $lon_deg * $D2R;

    # calculate alpha (rotation angle)
    my $relm = -$tlon + $lon_0; # opposite sign than T. Black's vecrot_rotlat
    my $srlm = sin($relm);
    my $crlm = cos($relm);
    my $sph = sin($tlat);
    my $cph = cos($tlat);
    my $cc = $cph  *  $crlm;
    my $tph = asin($cphi0 * $sph - $sphi0 * $cc);
    my $rctph = 1./cos($tph);
    my $sinalpha = $sphi0 * $srlm * $rctph;
    #my $cosalpha = ($cphi0 * $cph + $sphi0 * $sph * $crlm) * $rctph;
    my $alpha = asin($sinalpha)/$D2R;
    return($alpha);
}
    
sub rotLL_geo_to_ij {
    # this has been tested for the RR development version of Sept 2010l
    # I used the radius of the earth that relates the RR_devel grid spacing in km
    # to the grid spacing in degrees in the rotated system (which is the critical variable)
    # this had better be tested for other rotated LL grids!
    my($lat_g_deg,$lon_g_deg,$lat_0_deg,$lon_0_deg,
       $lat_g_SW_deg,$lon_g_SW_deg,$dxy_km) = @_;
    use POSIX;
    my $PI = acos(-1);
    my $D2R = $PI/180.;
    my $rearth = 6370.;		# this seems to be what works, although it ain't used elsewhere
    my $d_lon_r_per_cell = asin($dxy_km/$rearth)/$D2R;
    my $d_lat_r_per_cell = asin($dxy_km/$rearth)/$D2R;
    my($lat_r_deg,$lon_r_deg) =
	rotLL_geo_to_rot($lat_g_deg,$lon_g_deg,$lat_0_deg,$lon_0_deg);
    my($lat_r_SW_deg,$lon_r_SW_deg) =
	rotLL_geo_to_rot($lat_g_SW_deg,$lon_g_SW_deg,$lat_0_deg,$lon_0_deg);
    my $j = ($lon_r_deg - $lon_r_SW_deg)/$d_lon_r_per_cell + 1;
    my $i = ($lat_r_deg - $lat_r_SW_deg)/$d_lat_r_per_cell +1;
    return($i,$j);
}

sub rotLL_geo_to_rot {
    # THIS ASSUMES THAT THE CENTRAL MERIDAN POINTS NORTH (as it apparently does,
    # in spite of the value of POLE_LON in the grid definition)
    # input: geogrphic lat,lon, in degrees
    # output: geographic origin of rotated system, in degrees:
    my ($lat_g_deg,$lon_g_deg,$lat_0_deg,$lon_0_deg) = @_;
    use POSIX;
    my $PI = acos(-1);
    my $D2R = $PI/180.;
   
    my $lat_g = $lat_g_deg * $D2R;
    my $lon_g = $lon_g_deg * $D2R;
    my $lat_0 = $lat_0_deg * $D2R;
    my $lon_0 = $lon_0_deg * $D2R;
    # from http://www.emc.ncep.noaa.gov/mmb/research/FAQ-eta.html#rotatedlatlongrid
    my $X = cos($lat_0) *  cos($lat_g) *  cos($lon_g - $lon_0) + sin($lat_0) *  sin($lat_g);
    my $Y = cos($lat_g) *  sin($lon_g - $lon_0);
    my $Z = - sin($lat_0) *  cos($lat_g) *  cos($lon_g - $lon_0) + cos($lat_0) *  sin($lat_g);
    #print "X, Y, Z: $X, $Y, $Z\n";
    my $lat_r = atan($Z / sqrt($X **2 + $Y**2) );
    my $lon_r = atan ($Y / $X );
    # (if X < 0, add pi radians)
    if($X < 0) {$lon_r += $PI;}
    if($lon_r > $PI) { $lon_r -= 2*$PI;}
    if($lon_r < -$PI) {$lon_r += 2*$PI;}
    my $lat_r_deg = $lat_r/$D2R;
    my $lon_r_deg = $lon_r/$D2R;
    return($lat_r_deg,$lon_r_deg);
}

sub rotLL_rot_to_geo {
    # input:
    # lat,lon in rotated system, in degrees
    # geographic origin of rotated system, in degrees:
    my ($lat_r_deg,$lon_r_deg,$lat_0_deg,$lon_0_deg) = @_;
    #print "$lat_r_deg,$lon_r_deg,$lat_0_deg,$lon_0_deg\n";
    use POSIX;
    my $PI = acos(-1);
    my $D2R = $PI/180.;
   
    my $lat_r = $lat_r_deg*$D2R;
    my $lon_r = $lon_r_deg*$D2R;
    my $lat_0 = $lat_0_deg*$D2R;
    my $lon_0 = $lon_0_deg*$D2R;
    
    my $lat_g = asin(sin($lat_r)*cos($lat_0) + cos($lat_r)*sin($lat_0)*cos($lon_r));
    my $lat_g_deg = $lat_g/$D2R;
    my $factor = acos(cos($lat_r)*cos($lon_r)/(cos($lat_g)* cos($lat_0)) - tan($lat_g)*tan($lat_0));
    if($lon_r < 0) {
	$factor = -$factor;
    }
    my $lon_g_deg = ($lon_0 + $factor)/$D2R;
    if($lon_g_deg < -180) {$lon_g_deg += 360;}
    #print "$lat_g_deg,$lon_g_deg\n";
    return($lat_g_deg,$lon_g_deg);
}
