#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>
#include <math.h>
#include <unistd.h>
#include "ceil_stations.h"

int fill_rotLL_ceil_values(STATION *sta[],int n_stations,
			    char *filename,int grib_type, int grid_type, char *tmp_file,
			    int DEBUG) {
  FILE *input = NULL;
  char line[400];
  int floats_read=0;
  int floats_to_read=0;
  STATION *sp;
  int i,xi,yj,xi1,yj1;
  float x00,x01,x10,x11;
  int field_index;
  float xreal,yreal,rem_x,rem_y;
  float sfc_hgt,ceil_msl,ceil_agl;
  int g3_fields[] = {};
  int n_g3_fields = 0;
  /* 7 = HGT. level 'sfc' is hardwared in agrib_ceil.c for now */
  int g2_fields[] = {7,7};
  int n_g2_fields = 2;
  int no_column = -1;
  int istatus=0;
  time_t startClock;
  time_t endClock;
  float endSecs;
  long int ticks_per_sec;
  float alat,elon;
  int n_out=0;
  int n_zero_ceils=0;
  int n_good_ceils=0;
   
  /* HARDWIRE FOR RR rotLL grid */

  float lat_0_deg;
  float lon_0_deg;
  float lat_g_SW_deg;
  float lon_g_SW_deg;
  float dxLL;
  int nxLL;
  int nyLL;
  int nzLL ;

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
  }


  float dx = dxLL;
  int nx = nxLL;
  int ny = nyLL;
  int nz = nzLL;          /* not needed, since n_g3_fields = 0. */



  float *g3; 
  float *g2;

  void rotLL_geo_to_ij(float lat_g_deg,float lon_g_deg,float lat_0_deg,float lon_0_deg,
		       float lat_g_SW_deg,float lon_g_SW_deg,float dx,
		       float *pxi,float *pxj);
  void rotLL_ij_to_geo(float i,float j,float lat_0_deg,float lon_0_deg,
		       float lat_g_SW_deg,float lon_g_SW_deg,float dxy_km,
		       float *lat_g_deg,float *lon_g_deg);
  int agrib_ceil(int *nz_ptr, int *n_g3_fields,int *g3_fields,
	     int *n_g2_fields,int *g2_fields,
	     float *G3, float *G2,int *i_column,int *j_column,
	     char *filename, int *istatus_ptr );

  /* read grib file */
  /* the RR files have 'sfc' and 'cld base' under 'HGT',
     but the RUC files have 'cld base' under 'DIST'
     so correct for the RR files */
  g2_fields[1] = 7;
  
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
    /* printf("reading grib file %s\n",filename);*/
    (void)agrib_ceil(&nz,&n_g3_fields,g3_fields,
		 &n_g2_fields,g2_fields,
		 g3,g2,
		 &no_column,&no_column,
		 filename,&istatus);
  } else {
    /* grib2 */
    snprintf(line,500,"./make_grib2_ceil_tmp_file.pl %s %s %d",
	     filename,tmp_file,grib_type);
    printf("command is %s\n",line);
    system(line);
    printf("finished dumping grib file to tmp file: %s\n",tmp_file);
    /* now read the dump file. */
    if ((input = fopen(tmp_file,"r")) == NULL) {
      fprintf(stderr,"could not open file: %s\n", tmp_file);
      exit(7);
    }
    floats_to_read = n_g3_fields*nx*ny*nz + n_g2_fields*nx*ny;
    floats_read = fread(g3,sizeof(float),n_g3_fields*nx*ny*nz,input);
    printf("3d floats read: %d\n",floats_read);
    floats_read += fread(g2,sizeof(float),n_g2_fields*nx*ny,input);
    printf("total floats read: %d\n",floats_read);
    if(floats_read == floats_to_read) {
      printf("SUCCESS\n");
    } else {
      printf("%d floats read. Should have read %d\n",
	     floats_read,floats_to_read);
      exit(8);
    }
  }
  endClock = times(NULL);
  endClock -= startClock;
  endSecs = ((float)endClock)/ticks_per_sec;  
  printf("%.3f sec to read grib file\n",endSecs);
  if(istatus != 0) {
    printf("problem with agrib_ceil.c. status = %d\n",istatus);
    exit(istatus);
  }

  /* loop over sites */
  for(i=0;i<n_stations;i++) {
    sp = sta[i];
    alat = sp->lat;
    elon = sp->lon;
   /* get the appropriate i,j */
    rotLL_geo_to_ij(alat,elon,lat_0_deg,lon_0_deg,
		    lat_g_SW_deg,lon_g_SW_deg,dx,&yreal,&xreal);
    /* printf("xreal,yreal = %f %f\n",xreal,yreal);*/
    /* get nearest x,y point */
    xi = (int)(xreal+0.5);
    yj = (int)(yreal+0.5);
    if(xi < 0 || xi > nx-1 ||
       yj < 0 || yj > ny-1) {
      if(DEBUG == 2) {
	printf("out of domain: ");
	printf("Station %d: %.2f %.2f %.2f %.2f\n",
	       sp->sta_id,alat,elon,xreal,yreal);
      }
      n_out++;
      sp->sta_id = -1;
      continue;
    }
    field_index = 0;		/* DIST, sfc */
    sfc_hgt = g2[xi  + nx*(yj  + ny*field_index)];
    field_index = 1;		/* DIST, cld base */
    ceil_msl = g2[xi  + nx*(yj  + ny*field_index)];
    if(ceil_msl < -1000 ||
       ceil_msl > 1e10) {
      ceil_agl = 6000;
    } else if(ceil_msl < 0) {
      /* weird '-1's in the grib files */
      printf("strange ceiling: %f\n",ceil_msl);
      ceil_agl = 0;
      n_zero_ceils++;
    } else {
      ceil_agl = (ceil_msl - sfc_hgt)*0.32808; /* m -> tens of ft */
      /*printf("ceil_agl: %.2f sfc: %.2f, base: %.2f\n",
       *ceil_agl,sfc_hgt,ceil_msl);
       */
      n_good_ceils++;
      if(ceil_agl < 0) {
	if(DEBUG == 1) {
	  printf("negative AGL ceiling for %d: %f %f\n",
		 sp->sta_id,ceil_msl,sfc_hgt);
	}
	ceil_agl = 0;
	n_zero_ceils++;
      }
    }
    sp->ceil = ceil_agl;
    
  }

  printf("%d stations out of domain\n",
	 n_out);
  printf("%d stations with zero ceilings, %d with finite ceilings\n",
	 n_zero_ceils,n_good_ceils);
  return(n_zero_ceils);
}

