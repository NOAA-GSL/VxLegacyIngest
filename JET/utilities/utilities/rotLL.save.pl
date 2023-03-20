#!/usr/bin/perl

use POSIX;
my $PI = acos(-1);
my $D2R = $PI/180.;

my @lats = (2.227524, 53.49178, 53.49176, 2.227517,5.211449,33.59401,47.5);
my @lons = (-140.4815, 162.9838, -10.98379, -67.51849,-140.0393,-130.1077,-104.0);
for($i=0;$i<@lats;$i++) {
    
my $lat_g_deg = $lats[$i];
my $lat_g = $lat_g_deg*$D2R;
my $lon_g_deg = $lons[$i];
my $lon_g = $lon_g_deg*$D2R;

my $lat_0 = 47.5*$D2R;
my $lon_0 = -104.*$D2R;

my $X = cos($lat_0)* cos($lat_g)* cos($lon_g - $lon_0) + sin($lat_0)* sin($lat_g);
my $Y = cos($lat_g)* sin($lon_g - $lon_0);
my $Z = - sin($lat_0)* cos($lat_g)* cos($lon_g - $lon_0) + cos($lat_0)* sin($lat_g);
#print "X, Y, Z: $X, $Y, $Z\n";
my $lat_r = atan($Z / sqrt($X**2 + $Y**2) );
my $lon_r = atan ($Y / $X );
# (if X < 0, add pi radians)
if($X < 0) {$lon_r += $PI;}
if($lon_r > $PI) { $lon_r -= 2*$PI;}
if($lon_r < -$PI) {$lon_r += 2*$PI;}
my $lat_r_deg = $lat_r/$D2R;
my $lon_r_deg = $lon_r/$D2R;

#Now find the geographic lat/lon of any point for which the rotated lat/lon are known.
my $echo_lat_g_deg = asin(sin($lat_r)*cos($lat_0) + cos($lat_r)*sin($lat_0)*cos($lon_r))/$D2R;
my $factor = acos(cos($lat_r)*cos($lon_r)/(cos($lat_g)* cos($lat_0)) - tan($lat_g)*tan($lat_0));
if($lon_r < 0) {
    $factor = -$factor;
}
my $echo_lon_g_deg = ($lon_0 + $factor)/$D2R;
if($echo_lon_g_deg < -180) {$echo_lon_g_deg += 360;}

# it could be that for lat, the spacing is 0.1214039 deg/grid cell
#                  for lon, the spacing is 0.1215119 deg/grid cell
# so:
my $ny = 568;
my $tot_lat_r = 2* 34.478735;
my $d_lat_r_per_cell = $tot_lat_r/($ny-1);
my $nx = 759;
my $tot_lon_r = 2 * 46.11378;
my $d_lon_r_per_cell = $tot_lon_r/($nx-1);
my $i = ($lon_r_deg + 46.11378)/$d_lon_r_per_cell + 1;
my $j = ($lat_r_deg + 34.4787357)/$d_lat_r_per_cell +1;

printf("input $lat_g_deg/$lon_g_deg, rotated: $lat_r_deg/$lon_r_deg, echoed $echo_lat_g_deg/$echo_lon_g_deg".
    " j/i (1 based) %.1f/%.1f\n",$j,$i);
}
