#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>
#include <math.h>
#include <unistd.h>
#include "stations_test.h"

void fill_surface_values_q_all(STATION *sta[],int n_stations,
			   char *filename,char *tmp_file, int grib_type,
			       int grid_type,
			   int nx, int ny,int nz,
			   float alat1,float elon1, float dx,
			   float elonv,float alattan,
			   int rh_flag,int DEBUG) {
  FILE *input;
  FILE *test_file;
  char line[500];
  STATION *sp;
  int i,j,xi,yj,xi1,yj1;
  float x00,x01,x10,x11;
  int field_index;
  float xreal,yreal,rem_x,rem_y,x_delta,y_delta,delta;
  float interp_value[5];
  float SLP,Td,U,V,T,RH,VGTYP;
  float ws;
  int g3_fields[] = {};
  int n_g3_fields = 0;
  /* SLP, DPT, U, V, T, RH, VGTYP */
  int g2_fields[] = {2,17,33,34,11,52,225};
  int n_g2_fields = 7;
  int no_column = -1;
  int istatus=0;
  time_t startClock;
  time_t endClock;
  float endSecs;
  long int ticks_per_sec;
  float alat,elon;
  float rotcon = 0;
  float dlon;
  float deg_to_radians = 0.0174533;
  float theta;			/* degrees to rotate winds from RUC coords */
  float radians;
  long wd;
  int n_out=0;
  int n_bad=0;
  float r_min_land,r,bearing_land;
  float r_min_wat,bearing_wat;
  int i_min_land,j_min_land,in,jn,some_land_wat_dif;
  int i_min_wat,j_min_wat;
  int i_diff = 0;
  int floats_to_read=0;
  int floats_to_read_wo_vgtyp=0;
  int floats_read=0;
  int x_near,y_near;

    /*  HARDWIRE FOR RR rotLL grid */
  /*  float lat_0_deg = 47.5;
  float lon_0_deg = -104.;
  float lat_g_SW_deg = 2.227524;
  float lon_g_SW_deg = -140.4815;
  float dxLL = 13.54508;
  int nxLL = 758;
  int nyLL = 567;
  int nzLL = 50;*/

  /* for RAP rotLL grid */
  float lat_0_deg;
  float lon_0_deg;
  float lat_g_SW_deg;
  float lon_g_SW_deg;
  float dxLL;
  int nxLL;
  int nyLL;
  int nzLL ;

   
  float *g3; 
  float *g2;
  int *gsoil;			/* =1 for land, = -1 for water */

  void get_ij_LL(float alat,float elon, float ddeg, float *pxi,float *pxj);
  void rotLL_geo_to_ij(float lat_g_deg,float lon_g_deg,float lat_0_deg,float lon_0_deg,
		       float lat_g_SW_deg,float lon_g_SW_deg,float dxy_km,
		       float *pyj,float *pxi);
  void rotLL_ij_to_geo(float i,float j,float lat_0_deg,float lon_0_deg,
		       float lat_g_SW_deg,float lon_g_SW_deg,float dxy_km,
		       float *lat_g_deg,float *lon_g_deg);
  double rotLL_wind2true_deg(double lat_g_deg,double lon_g_deg,
			     double lat_0_deg,double lon_0_deg);
  void w3fb06(float alat,float elon,
	    float alat1,float elon1,float dx,float elonv,
	    float *pxi,float *pxj);
  void w3fb11(float alat,float elon,
	      float alat1,float elon1,float dx,float elonv,float alatan,
	      float *pxi,float *pxj);
  void w3fb08(float alat,float elon,
	      float alat1,float elon1,float alatan,float dx,
	      float *pxi,float *pxj);
  int agrib_(int *nz_ptr, int *n_g3_fields,int *g3_fields,
	     int *n_g2_fields,int *g2_fields,
	     float *G3, float *G2,int *i_column,int *j_column,
	     char *filename, int *istatus_ptr );
  void read_soil_file(int nx,int ny, int *gsoil);

  float rh_from_spfh(float p, float tk,float q);


  /* if dx == 0, we have a lat/lon grid */
  if(grid_type == 20) {
    /* we have the OLD rotated lat/lon grid */
    lat_0_deg = 47.5;
    lon_0_deg = -104.;
    lat_g_SW_deg = 2.227524;
    lon_g_SW_deg = -140.4815;
    dxLL = 13.54508;
    nxLL = 758;
    nyLL = 567;
    nzLL = 50;
    dx = dxLL;
    nx = nxLL;
    ny = nyLL;
    nz = nzLL;          /* not needed, since n_g3_fields = 0. */
  } else if(grid_type == 21) {
    /* we have the NEW rotated lat/lon grid */
    lat_0_deg = 54.0;
    lon_0_deg = -106.0;
    lat_g_SW_deg =  -10.5906;
    lon_g_SW_deg = -139.0858;
    dxLL = 13.54508;
    nxLL = 953;
    nyLL = 834;
    nzLL = 50;
    dx = dxLL;
    nx = nxLL;
    ny = nyLL;
    nz = nzLL;          /* not needed, since n_g3_fields = 0. */
  } else if(grid_type == 22) {
    /* we have the NEW rotated lat/lon grid for RRFS_NA_13km */
    lat_0_deg = 54.0;
    lon_0_deg = -106.0;
    lat_g_SW_deg =  -8.052698;
    lon_g_SW_deg = -139.561;
    /*lat_g_SW_deg =  -48.576854;
 *     lon_g_SW_deg = -55.825378;*/
    dxLL = 13.0;
    nxLL = 956;
    nyLL = 831;
    nzLL = 64;
    dx = dxLL;
    nx = nxLL;
    ny = nyLL;
    nz = nzLL;          /* not needed, since n_g3_fields = 0. */
  } else if(grid_type == 23) {
    /* we have the NEW rotated lat/lon grid for RRFS_NA_3km */
    lat_0_deg = 48.0;
    lon_0_deg = -112.0;
    lat_g_SW_deg =  1.592547;
    lon_g_SW_deg = -152.6942;
    dxLL = 3.0;
    nxLL = 4081;
    nyLL = 2641;
    nzLL = 64;
    dx = dxLL;
    nx = nxLL;
    ny = nyLL;
    nz = nzLL;          /* not needed, since n_g3_fields = 0. */
  }

    printf("xue2 for g3 %d %d %d %d\n",
	   n_g3_fields,nx,ny,nz);

    printf("xue2 dx %.2f\n",
	   dx);

  /* if dx == 0, we have a lat/lon grid */
  if(dx == 0) {
    dx = dxLL;
    nx = nxLL;
    ny = nyLL;
    nz = nzLL;		/* not needed, since n_g3_fields = 0. */
  }


  printf("alat1 %f, elon1 %f, dx %f, elonv %f,alattan %f\n",
	 alat1,elon1,dx,elonv,alattan);

  test_file = fopen("/whome/amb-verif/ruc_madis_surface/legacy_ingest_station_list.txt","w");
  fprintf(test_file,"Station, ID, x, y\n");
  fprintf(test_file,"##############################\n");

  /* loop over sites */
  for(i=0;i<n_stations;i++) {
    sp = sta[i];
    if(i < 0) {
      printf("here 8 %d ",i);
      printstation(sp);
    }
    alat = sp->lat;
    elon = sp->lon;

    /* xue modify here */
    if (grid_type==1){ 
      /* xue add lambert*/
      /*      printf("calling lambert ");*/
      w3fb11(alat,elon,alat1,elon1,dx,elonv,alattan,&xreal,&yreal);
    } else if (grid_type==3){
      /* polar */
      /*printf("calling polar ");*/
      w3fb06(alat,elon,alat1,elon1,dx,elonv,&xreal,&yreal);
    } else if (grid_type==5){
      /* mercator */
      /* printf("calling mercator ");*/
      w3fb08(alat,elon,alat1,elon1,alattan,dx,&xreal,&yreal);
      if (sp->sta_id == 16131) {
        printf("w3fb08 %.2f, %.2f, %.2f, %.2f, %.2f, %.2f \n",alat,elon,alat1,elon1,alattan,dx);
        printf("output %.2f, %.2f \n",xreal,yreal);
      }
    } else if(grid_type==11) {
      /* LatLon (LL) */
      get_ij_LL(alat,elon,dx,&xreal,&yreal);
    }  else if (grid_type == 20 || grid_type == 21 || grid_type == 22 || grid_type == 23){ 
      /*      printf("calling rotate ");*/
      /* rotated LL coords grid_type =20 21*/
      rotLL_geo_to_ij(alat,elon,lat_0_deg,lon_0_deg,
                      lat_g_SW_deg,lon_g_SW_deg,dxLL,
                      &yreal,&xreal);
    }
    /*xue 
    exit(1);*/
    /* end xue modify here */


    /* get x,y point */
    xi = (int)xreal;
    yj = (int)yreal;
    if(xi < 0 || xi > nx-2 ||
       yj < 0 || yj > ny-2) {
      if(n_out < 10 && DEBUG > 0) {
	printf("out of domain. Setting sta_id to -1 (showing first 10): \n");
	printf("Station %d: %.2f %.2f %.2f %.2f\n",
	       sp->sta_id,alat,elon,xreal,yreal);
      }
      n_out++;
      sp->sta_id = -1;
      continue;
    }
    xi1 = xi+1;
    yj1 = yj+1;
    rem_x = xreal - xi;
    rem_y = yreal - yj;

    if (sp->sta_id == 16131) {
      printf("xi, yj, xi1, yj1 %d, %d, %d, %d \n",xi,yj,xi1,yj1);
    }

    /* get nearest neighbor (for land use) */
    x_near = xi;
    y_near = yj;
    if(rem_x > 0.5) {
      x_near++;
    }
    if(rem_y > 0.5) {
      y_near++;
    }


    x_delta = xreal - x_near;
    y_delta = yreal - y_near;
    delta = sp->lon + 360;
    printf("%s, %d, %.4f, %.4f, %d, %d\n",sp->name,sp->sta_id,sp->lat,delta,x_near,y_near);
    fprintf(test_file,"%s, %d, %d, %d\n",sp->name,sp->sta_id,x_near,y_near);
    /*fprintf(test_file,"%d %f %f %d %d %f\n",sp->sta_id,sp->lat,sp->lon,x_near,y_near,delta);*/

  }
  fclose(test_file);
  printf("%d stations out of domain\n",
	 n_out);
}

/* grid 11 is s to N, W to E scan */
/* default from wgrib is order: we:sn */
void get_ij_LL(float alat,float elon, float ddeg, float *pxi,float *pxj) {
  if(elon < 0) {
    elon += 360;
  }
  *pxi = elon /ddeg;
  *pxj = (90-alat)/ddeg;
}

void read_soil_file(int nx, int ny,int *gsoil) {
  FILE *fp = NULL;
  int i,j;
  float x;

  if(nx == 648) {
    fp = fopen("vegtype_usgs_RR1hLC.dat","r");
  } else if(nx == 758) {
    fp = fopen("vegtype_usgs_RR1hRotLL.dat","r");
  } else if(nx == 1799) {
    fp = fopen("vegtype_usgs_HRRR.dat","r");
  } else if(nx == 451) {
    fp = fopen("vegtype_usgs.dat","r");
  } else {
    printf("NO SOIL FILE AVAILABLE FOR THIS MODEL\n");
  }
  if(fp == NULL) {
    printf("ALL POINTS BEING SET TO 'LAND'\n");
    for(j=0;j<ny;j++) {
      for(i=0;i<nx;i++) {
        gsoil[i  + nx*j] = 1;
      }
    }
  } else {
    for(j=0;j<ny;j++) {
      for(i=0;i<nx;i++) {
        fscanf(fp,"%f",&x);
        if(x == 16.) {
          /* water */
          gsoil[i  + nx*j] = -1;
        } else {
          /* land */
          gsoil[i  + nx*j] = 1;
        }
      }
    }
  }
}
float rh_from_spfh(float p, float tk,float q) {
  /* ;;returns rh (0-1),
     ;; given pressure in pascals, t in kelvin
     ;; and specific humidity (q)
  */

  double esw_pascals,e_pascals,log10_e,dewpoint;
  double exnr,cpd_p,rovcp_p,pol,rh,qv;
  double tx,e,exner;

  cpd_p=1004.686;
  rovcp_p=0.285714;/* R/cp */
  exner = cpd_p*pow((p/100000.),rovcp_p);
  qv = q/(1.-q);
  
  /* Stan's way of calculating sat vap pressure: 
  tx = tk-273.15;
  pol = 0.99999683       + tx*(-0.90826951e-02 +
      tx*(0.78736169e-04   + tx*(-0.61117958e-06 +
      tx*(0.43884187e-08   + tx*(-0.29883885e-10 +
      tx*(0.21874425e-12   + tx*(-0.17892321e-14 +
      tx*(0.11112018e-16   + tx*(-0.30994571e-19)))))))));
  esw_old_pascals = 6.1078/pow(pol,8.) *100.; 
  */
  
  /* Rex's way of calculating sat vap pressure: */
  /* From Fan and Whiting (1987) as quoted in Fleming (1996): BAMS 77, p
     2229-2242, the saturation vapor pressure is given by: */
  esw_pascals=pow(10.,((10.286*tk - 2148.909)/(tk-35.85)));
  e = p*qv/(0.62197+qv);
  rh = e/esw_pascals;

  /* debugging code follows to compare dewpoint. Can remove this later */
  if(rh == 0) {
    dewpoint = 0;
  } else {
  
    /*printf("Temp: %f, rh %f Saturation: old,new= %f %f\n",
      tx,rh,esx,esw_pascals);*/
    
    e_pascals = rh*esw_pascals;
    log10_e = log10(e_pascals);
    
    /* invert the formula for esw to see the temperature at which
       e is the saturation value */
    
    dewpoint = ((-2148.909 + 35.85*log10_e)/(-10.286 + log10_e));
    /*printf("SPFH %.3f, rh %.3f dewpoint (k) = %.1f\n",
      q,rh,dewpoint);*/
  }
  
  return(rh);
}
  

  
