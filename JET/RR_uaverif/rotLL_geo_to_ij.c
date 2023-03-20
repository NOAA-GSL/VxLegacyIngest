#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>

void rotLL_geo_to_ij(float lat_g_deg,float lon_g_deg,float lat_0_deg,float lon_0_deg,
		     float lat_g_SW_deg,float lon_g_SW_deg,float dxy_km,
		     float *pxi,float *pxj)
{
  /*
    # this has been tested for the RR development version of Sept 2010l
    # I used the radius of the earth that relates the RR_devel grid spacing in km
    # to the grid spacing in degrees in the rotated system (which is the critical variable)
    # this had better be tested for other rotated LL grids!
  */
  double PI,D2R,rearth,d_lon_r_per_cell,d_lat_r_per_cell,lat_r_deg,lon_r_deg;
  double lat_r_SW_deg,lon_r_SW_deg;
  void rotLL_geo_to_rot(double lat_g_deg,double lon_g_deg,double lat_0_deg,double lon_0_deg,
			double *lat_r_deg,double *lon_r_deg);
  PI = acos(-1);
  D2R = PI/180.;
  rearth = 6370.;		/* this seems to be what works, although it ain't used elsewhere */
  d_lon_r_per_cell = asin(dxy_km/rearth)/D2R;
  d_lat_r_per_cell = asin(dxy_km/rearth)/D2R;
  rotLL_geo_to_rot(lat_g_deg,lon_g_deg,lat_0_deg,lon_0_deg,&lat_r_deg,&lon_r_deg);
  rotLL_geo_to_rot(lat_g_SW_deg,lon_g_SW_deg,lat_0_deg,lon_0_deg,&lat_r_SW_deg,&lon_r_SW_deg);
  *pxj = (lon_r_deg - lon_r_SW_deg)/d_lon_r_per_cell + 1;
  *pxi = (lat_r_deg - lat_r_SW_deg)/d_lat_r_per_cell +1;
}
