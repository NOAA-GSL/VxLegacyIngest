#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>

void rotLL_ij_to_geo(float i,float j,float lat_0_deg,float lon_0_deg,
		     float lat_g_SW_deg,float lon_g_SW_deg,float dxy_km,
		     float *lat_g_deg,float *lon_g_deg) {
  double PI,D2R,rearth,d_lon_r_per_cell,d_lat_r_per_cell,lat_r_deg,lon_r_deg;
  double lat_r_SW_deg,lon_r_SW_deg;
  double lat_g_deg_d,lon_g_deg_d;
  void rotLL_rot_to_geo(double lat_r_deg,double lon_r_deg,double lat_0_deg,double lon_0_deg,
			double *lat_g_deg,double *lon_g_deg);
  void rotLL_geo_to_rot(double lat_g_deg,double lon_g_deg,double lat_0_deg,double lon_0_deg,
			double *lat_r_deg,double *lon_r_deg);
  PI = acos(-1);
  D2R = PI/180.;
  rearth = 6370.;		/* this seems to be what works, although it ain't used elsewhere */
  
  d_lon_r_per_cell = asin(dxy_km/rearth)/D2R;
  d_lat_r_per_cell = asin(dxy_km/rearth)/D2R;
  rotLL_geo_to_rot(lat_g_SW_deg,lon_g_SW_deg,lat_0_deg,lon_0_deg,&lat_r_SW_deg,&lon_r_SW_deg);
  
  lon_r_deg = lon_r_SW_deg + j*d_lon_r_per_cell;
  lat_r_deg = lat_r_SW_deg + i*d_lat_r_per_cell;
  rotLL_rot_to_geo(lat_r_deg,lon_r_deg,lat_0_deg,lon_0_deg,
		   &lat_g_deg_d,&lon_g_deg_d);
  *lat_g_deg = (float)lat_g_deg_d;
  *lon_g_deg = (float)lon_g_deg_d;
}

/*
 * fortran callable version (note final underscore)
 */
void rotll_geo_to_ij_(float *lat_g_deg,float *lon_g_deg,float *lat_0_deg,float *lon_0_deg,
		     float *lat_g_SW_deg,float *lon_g_SW_deg,float *dxy_km,
		     float *pyj,float *pxi) {
  /* prototype */
  void rotLL_geo_to_ij(float lat_g_deg,float lon_g_deg,float lat_0_deg,float lon_0_deg,
		       float lat_g_SW_deg,float lon_g_SW_deg,float dxy_km,
		       float *pyj,float *pxi);
  
  rotLL_geo_to_ij(*lat_g_deg, *lon_g_deg, *lat_0_deg, *lon_0_deg,
		  *lat_g_SW_deg, *lon_g_SW_deg, *dxy_km,
		  pyj,pxi);
  /* for fortran, have indices start at 1 */
  *pyj++;
  *pxi++;
}

void rotLL_geo_to_ij(float lat_g_deg,float lon_g_deg,float lat_0_deg,float lon_0_deg,
		     float lat_g_SW_deg,float lon_g_SW_deg,float dxy_km,
		     float *pyj,float *pxi) {
  /*
    # this has been tested for the RR development version of Sept 2010l
    # I used the radius of the earth that relates the RR_devel grid spacing in km
    # to the grid spacing in degrees in the rotated system (which is the critical variable)
    # this had better be tested for other rotated LL grids!
    # THIS WAS TESTED ON 23-FEB-2017 AGAINST THE IJ PROVIDED BY
    # jet:~amb-verif/acars_TAM/grid_test.ncl with a current RAP file (using the new RotLL grid)
    # and the ij agreed to the nearest integer.
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
  /* printf("PI %f, D2R %f, dxy_km %f,dlat %f, dlon %f\n",
     PI,D2R,dxy_km,d_lat_r_per_cell,d_lon_r_per_cell);*/
  rotLL_geo_to_rot(lat_g_deg,lon_g_deg,lat_0_deg,lon_0_deg,&lat_r_deg,&lon_r_deg);
  rotLL_geo_to_rot(lat_g_SW_deg,lon_g_SW_deg,lat_0_deg,lon_0_deg,&lat_r_SW_deg,&lon_r_SW_deg);
  *pxi = (lon_r_deg - lon_r_SW_deg)/d_lon_r_per_cell;
  *pyj = (lat_r_deg - lat_r_SW_deg)/d_lat_r_per_cell;
}

void rotLL_geo_to_rot(double lat_g_deg,double lon_g_deg,double lat_0_deg,double lon_0_deg,
		      double *lat_r_deg,double *lon_r_deg) {
		      
  /*
    # THIS ASSUMES THAT THE CENTRAL MERIDAN POINTS NORTH (as it apparently does,
    # in spite of the value of POLE_LON in the grid definition)
    # input: geogrphic lat,lon, in degrees
    # output: geographic origin of rotated system, in degrees:
  */
  double PI,D2R,lat_g,lon_g,lat_0,lon_0,X,Y,Z,lat_r,lon_r;

  PI = acos(-1);
  D2R = PI/180.;
  lat_g = lat_g_deg * D2R;
  lon_g = lon_g_deg * D2R;
  lat_0 = lat_0_deg * D2R;
  lon_0 = lon_0_deg * D2R;
  /* from http://www.emc.ncep.noaa.gov/mmb/research/FAQ-eta.html#rotatedlatlongrid*/
  X = cos(lat_0) *  cos(lat_g) *  cos(lon_g - lon_0) + sin(lat_0) *  sin(lat_g);
  Y = cos(lat_g) *  sin(lon_g - lon_0);
  Z = - sin(lat_0) *  cos(lat_g) *  cos(lon_g - lon_0) + cos(lat_0) *  sin(lat_g);
  /* print "X, Y, Z: X, Y, Z\n";*/
  lat_r = atan(Z / sqrt(pow(X,2) + pow(Y,2)) );
  lon_r = atan (Y / X );
  if(X < 0) {lon_r += PI;}
  if(lon_r > PI) { lon_r -= 2*PI;}
  if(lon_r < -PI) {lon_r += 2*PI;}
  *lat_r_deg = lat_r/D2R;
  *lon_r_deg = lon_r/D2R;
}

void rotLL_rot_to_geo(double lat_r_deg,double lon_r_deg,double lat_0_deg,double lon_0_deg,
		      double *lat_g_deg,double *lon_g_deg) {
		      
  /*
    # THIS ASSUMES THAT THE CENTRAL MERIDAN POINTS NORTH (as it apparently does,
    # in spite of the value of POLE_LON in the grid definition)
    # input: geogrphic lat,lon, in degrees
    # output: geographic origin of rotated system, in degrees:
  */
  double PI,D2R,lat_g,lon_g,lat_0,lon_0,X,Y,Z,lat_r,lon_r,factor;

  PI = acos(-1);
  D2R = PI/180.;
  lat_r = lat_r_deg*D2R;
  lon_r = lon_r_deg*D2R;
  lat_0 = lat_0_deg*D2R;
  lon_0 = lon_0_deg*D2R;
    
  lat_g = asin(sin(lat_r)*cos(lat_0) + cos(lat_r)*sin(lat_0)*cos(lon_r));
  *lat_g_deg = lat_g/D2R;
  factor = acos(cos(lat_r)*cos(lon_r)/(cos(lat_g)* cos(lat_0)) - tan(lat_g)*tan(lat_0));
  if(lon_r < 0) {
    factor = -factor;
  }
  *lon_g_deg = (lon_0 + factor)/D2R;
  if(*lon_g_deg < -180) {
    *lon_g_deg += 360;
  }
}

/*
 * fortran-callable version of the routine below this one
 */
void rotll_wind2true_deg_(float *lat_g_deg,float *lon_g_deg,
			 float *lat_0_deg,float *lon_0_deg,
			 float *theta) {
  /* prototype: */
  double rotLL_wind2true_deg(double lat_g_deg,double lon_g_deg,
			     double lat_0_deg,double lon_0_deg);
  
  *theta = rotLL_wind2true_deg(*lat_g_deg, *lon_g_deg,
			       *lat_0_deg, *lon_0_deg);
  /* printf("%f %f %f %f %f\n",*lat_g_deg, *lon_g_deg,*lat_0_deg, *lon_0_deg,*theta);*/

}

double rotLL_wind2true_deg(double lat_g_deg,double lon_g_deg,
			   double lat_0_deg,double lon_0_deg) {
  double PI,D2R,lon_0,lat_0,sphi0,cphi0,tlat,tlon,relm,srlm,crlm,sph,cph,cc,tph,rctph;
  double alpha,sinalpha;
  
  PI = acos(-1);
  D2R = PI/180.;
  
  /* deal with origin of rotLL system */
  if(lon_0_deg < 0) {
    lon_0_deg += 360;
  }
  lon_0 = lon_0_deg * D2R;
  lat_0 = lat_0_deg * D2R;
  sphi0 = sin(lat_0);
  cphi0 = cos(lat_0);
  
  /* deal with input lat/lon*/
  tlat = lat_g_deg * D2R;
  tlon = lon_g_deg * D2R;

  /* calculate alpha (rotation angle) */
  relm = -tlon + lon_0; /* opposite sign than T. Black's vecrot_rotlat */
  srlm = sin(relm);
  crlm = cos(relm);
  sph = sin(tlat);
  cph = cos(tlat);
  cc = cph  *  crlm;
  tph = asin(cphi0 * sph - sphi0 * cc);
  rctph = 1./cos(tph);
  sinalpha = sphi0 * srlm * rctph;
  alpha = -asin(sinalpha)/D2R;
  /* printf("sinalpha is %f, alpha is %f\n",sinalpha,alpha);*/
  return(alpha);
}
