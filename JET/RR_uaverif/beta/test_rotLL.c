#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <sys/types.h>
#include <unistd.h>
#include "gen_soundings.h"

main (int argc, char *argv[]) {
  double rotLL_wind2true_deg(double lat_g_deg,double lon_g_deg,
			     double lat_0_deg,double lon_0_deg);
  void rotLL_ij_to_geo(float i,float j,float lat_0_deg,float lon_0_deg,
		       float lat_g_SW_deg,float lon_g_SW_deg,float dxy_km,
		       float *lat_g_deg,float *lon_g_deg);
 double theta;
 float lat_g_deg,lon_g_deg;
  /* HARDWIRE FOR RR rotLL grid */
  float lat_0_deg = 47.5;
  float lon_0_deg = -104.;
  float lat_g_SW_deg = 2.227524;
  float lon_g_SW_deg = -140.4815;
  float dxy_km = 13.54508;
  int nx = 758;
  int ny = 567;
  int nz = 50;
  int i,j;
  
  for(i=1;i< ny;i+=10) {
    for(j=1;j<nx;j+=10) {
      /* get grid lat/lon for this ij */
      rotLL_ij_to_geo(i,j,lat_0_deg,lon_0_deg,
		      lat_g_SW_deg,lon_g_SW_deg,dxy_km,
		      &lat_g_deg,&lon_g_deg);
      theta = rotLL_wind2true_deg(lat_g_deg,lon_g_deg,
				  lat_0_deg,lon_0_deg);
      printf("(%d,%d) %.4f %.4f %.4f\n",
	     i,j,lat_g_deg,lon_g_deg,theta);
    }
  }
}
