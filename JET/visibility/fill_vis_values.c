#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>
#include <math.h>
#include <unistd.h>
#include "vis_stations.h"

void fill_vis_values(STATION *sta[],int n_stations,
		     char *filename,int grib_type,int grid_type,char *tmp_file,
                     int nx, int ny,int nz,
		     float alat1,float elon1, float dx,
		      float elonv,float alattan,int DEBUG) {
  STATION *sp;
  FILE *fp;
  int i,xi,yj,xi1,yj1,j;
  int nx_in,ny_in;
  float x00,x01,x10,x11;
  int field_index;
  float xreal,yreal,rem_x,rem_y;
  float vis_m,vis100;
  int g3_fields[] = {};
  int n_g3_fields = 0;
  /* 19 = VIS */
  int g2_fields[] = {20};
  int n_g2_fields = 1;
  int no_column = -1;
  int istatus=0;
  time_t startClock;
  time_t endClock;
  float endSecs;
  long int ticks_per_sec;
  float alat,elon;
  int n_out=0;
  float min_vis_m = 1e10;
  float max_vis_m = 0;
   
  float *g3; 
  float *g2;

  /* for RAP rotLL grid */
  float lat_0_deg;
  float lon_0_deg;
  float lat_g_SW_deg;
  float lon_g_SW_deg;
  float dxLL;
  int nxLL;
  int nyLL;
  int nzLL ;
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

  void rotLL_geo_to_ij(float lat_g_deg,float lon_g_deg,float lat_0_deg,float lon_0_deg,
                       float lat_g_SW_deg,float lon_g_SW_deg,float dxy_km,
                       float *pyj,float *pxi);
  void rotLL_ij_to_geo(float i,float j,float lat_0_deg,float lon_0_deg,
                       float lat_g_SW_deg,float lon_g_SW_deg,float dxy_km,
                       float *lat_g_deg,float *lon_g_deg);



  void w3fb11(float alat,float elon,
	    float alat1,float elon1,float dx,float elonv,float alatan,
	    float *pxi,float *pxj);
  void w3fb06(float alat,float elon,
	    float alat1,float elon1,float dx,float elonv,
	    float *pxi,float *pxj);
  void w3fb12(float xi,float xj,float alat1,float elon1,
	    float dx,float elonv,float alatan,
	    float *alat,float *elon);
  void w3fb08(float alat,float elon,
              float alat1,float elon1,float alatan,float dx,
              float *pxi,float *pxj);
  int agrib_vis_(int *nz_ptr, int *n_g3_fields,int *g3_fields,
             int *n_g2_fields,int *g2_fields,
             float *G3, float *G2,int *i_column,int *j_column,
             char *filename, int *istatus_ptr );


  /* read grib file */

  
  g3 = (float *)malloc(sizeof(float)*n_g3_fields*nx*ny*nz);
  if(g3 == NULL) {
    printf("not enough space for g3 %d %d %d %d\n",
	   n_g3_fields,nx,ny,nz);
    exit(1);
  }
  g2 = (float *)malloc(sizeof(float)*n_g2_fields*nx*ny);
  if(g2 == NULL) {
    printf("not enough space for g2\n");
    exit(1);
  }
  
  ticks_per_sec = sysconf(_SC_CLK_TCK);
  startClock = times(NULL);

  if(grib_type == 1) {
    printf("reading grib file %s\n",filename);
    agrib_vis_(&nz,&n_g3_fields,g3_fields,
         &n_g2_fields,g2_fields,
         g3,g2,
         &no_column,&no_column,
         filename,&istatus);
    nx_in = nx;
    ny_in = ny;
  } else {
    /* grib2 */
    printf("reading grib2 text file %s\n",tmp_file);
    fp = fopen(tmp_file,"r");
    if(fp   == NULL) {
      printf("cannot open %s\n",tmp_file);
      exit(1);
    }
    printf("opened %s\n",tmp_file);
  
    fscanf(fp,"%d %d",&nx_in,&ny_in);
    if(nx_in != nx || ny_in != ny) {
      printf("empty file, or dimensions don't match! %s: %d/%d, expected: %d/%d\n",
	     tmp_file,nx_in,ny_in,nx,ny);
      if(grid_type == 21 && nx_in == -1) {
	printf("OK for grid 21 (rotated LatLon)\n");
      } else {
	exit(2);
      }
    }
    field_index = 0;	/* VIS */
    for(j=0;j<ny;j++) {
      for(i=0;i<nx;i++) {
        fscanf(fp,"%f",
	       &g2[i  + nx*(j  + ny*field_index)]);
        /*printf("value is %f\n",g2[i*ny+j]);*/
      }
    }
  }
  printf("nx_in %d ny_in %d alat1 %f, elon1 %f, dx %f, elonv %f,alattan %f\n",
	 nx_in,ny_in,alat1,elon1,dx,elonv,alattan);

  /* loop over sites */
  for(i=0;i<n_stations;i++) {
    sp = sta[i];
    alat = sp->lat;
    elon = sp->lon;
    /*printf("station %d lat %f, lon %f\n",
      alat,elon);*/
    /* get the appropriate i,j */

    if(grid_type == 20 || grid_type == 21 || grid_type == 22 || grid_type == 23) {
      rotLL_geo_to_ij(alat,elon,lat_0_deg,lon_0_deg,
                      lat_g_SW_deg,lon_g_SW_deg,dxLL,
                      &yreal,&xreal);
    } else if (grid_type==3) {
      /* polar */
      w3fb06(alat,elon,alat1,elon1,dx,elonv,&xreal,&yreal);
    } else if (grid_type==1){
      /* lambert*/
      /*      printf("calling lambert ");*/
      w3fb11(alat,elon,alat1,elon1,dx,elonv,alattan,&xreal,&yreal);
    } else if (grid_type==5){
      /* mercator */
      /* printf("calling mercator ");*/
      w3fb08(alat,elon,alat1,elon1,alattan,dx,&xreal,&yreal);
    }

    /* get nearest x,y point */
    xi = (int)(xreal+0.5);
    yj = (int)(yreal+0.5);
    if(xi < 0 || xi > nx-1 ||
       yj < 0 || yj > ny-1) {
      if(DEBUG == 1) {
	/*
	printf("out of domain: ");
	printf("Station %d: %.2f %.2f %.2f %.2f\n",
	       sp->sta_id,alat,elon,xreal,yreal);
	*/
      }
      n_out++;
      sp->sta_id = -1;
      continue;
    }
    field_index = 0;		/* VIS */
    vis_m = g2[xi  + nx*(yj  + ny*field_index)];
    if(vis_m > max_vis_m) {
      max_vis_m = vis_m;
    }
    if(vis_m < min_vis_m) {
      min_vis_m = vis_m;
    }
    vis100 = vis_m*100/1609.344; /* m -> 100th of statute miles */
    if(vis100 > 65535) {
      vis100 = 65535;
    }
    sp->vis100 = vis100;
  }

  printf("%d stations out of RUC domain\n",
	 n_out);  
}

