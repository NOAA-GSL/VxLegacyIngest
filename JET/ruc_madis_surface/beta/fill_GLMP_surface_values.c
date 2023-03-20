#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>
#include <math.h>
#include <unistd.h>
#include "stations.h"

void fill_GLMP_surface_values(STATION *sta[],int n_stations,
			   char *filename,char *tmp_file, int grib_type,
			   int nx, int ny,int nz,
			   float alat1,float elon1, float dx,
			   float elonv,float alattan,
			   int rh_flag,int DEBUG) {
  FILE *input;
  char line[500];
  STATION *sp;
  int i,j,xi,yj,xi1,yj1;
  float x00,x01,x10,x11;
  int field_index;
  float xreal,yreal,rem_x,rem_y;
  float interp_value[5];
  float SLP,Td,U,V,T,RH;
  float ws;
  int n_g2_fields = 2;
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
  float r_min_land,r,bearing_land;
  float r_min_wat,bearing_wat;
  int i_min_land,j_min_land,in,jn,some_land_wat_dif;
  int i_min_wat,j_min_wat;
  int i_diff = 0;
  int floats_to_read=0;
  int floats_read=0;

    /* HARDWIRE FOR RR rotLL grid */
  float lat_0_deg = 47.5;
  float lon_0_deg = -104.;
  float lat_g_SW_deg = 2.227524;
  float lon_g_SW_deg = -140.4815;
  float dxLL = 13.54508;
  int nxLL = 758;
  int nyLL = 567;
  int nzLL = 50;

   
  float *g2;
  int *gsoil;			/* =1 for land, = -1 for water */

  void rotLL_geo_to_ij(float lat_g_deg,float lon_g_deg,float lat_0_deg,float lon_0_deg,
		       float lat_g_SW_deg,float lon_g_SW_deg,float dxy_km,
		       float *pyj,float *pxi);
  void rotLL_ij_to_geo(float i,float j,float lat_0_deg,float lon_0_deg,
		       float lat_g_SW_deg,float lon_g_SW_deg,float dxy_km,
		       float *lat_g_deg,float *lon_g_deg);
  double rotLL_wind2true_deg(double lat_g_deg,double lon_g_deg,
			     double lat_0_deg,double lon_0_deg);
  void w3fb11(float alat,float elon,
	    float alat1,float elon1,float dx,float elonv,float alatan,
	    float *pxi,float *pxj);
  int agrib_(int *nz_ptr, int *n_g3_fields,int *g3_fields,
	     int *n_g2_fields,int *g2_fields,
	     float *G3, float *G2,int *i_column,int *j_column,
	     char *filename, int *istatus_ptr );
  void read_soil_file(int nx,int ny, int *gsoil);
  float rh_from_spfh(float p, float tk,float q);

  /* if dx == 0, we have a lat/lon grid */
  if(dx == 0) {
    dx = dxLL;
    nx = nxLL;
    ny = nyLL;
    nz = nzLL;		/* not needed, since n_g3_fields = 0. */
  }

  /* read grib file */
  
  g2 = (float *)malloc(sizeof(float)*n_g2_fields*nx*ny);
  if(g2 == NULL) {
    printf("not enough space for g2\n");
    exit(1);
  }
  
  gsoil = (int *)malloc(sizeof(int)*nx*ny);
  if(gsoil == NULL) {
    printf("not enough space for gsoil\n");
    exit(1);
  }

  read_soil_file(nx,ny,gsoil);
  /* for debugging 
  for(j=ny-1;j>=0;j=j-4) {
    for(i=0;i<nx;i=i+4) {
      if(gsoil[i  + nx*j] == -1) {
	printf(".");
      } else {
	printf("+");
      }
    }
    printf("\n");
    }  */
  
  ticks_per_sec = sysconf(_SC_CLK_TCK);
  startClock = times(NULL);

    /* grib2 */
    snprintf(line,500,"./make_GLMP_sfc_tmp_file.pl %s %s",
	     filename,tmp_file);
    printf("command is %s\n",line);
    system(line);
    printf("finished dumping grib file\n");
    /* now read the dump file. */
    if ((input = fopen(tmp_file,"r")) == NULL) {
      fprintf(stderr,"could not open file: %s\n", tmp_file);
      exit(7);
    }
    floats_to_read = n_g2_fields*nx*ny;
    floats_read = fread(g2,sizeof(float),n_g2_fields*nx*ny,input);
    printf("total floats read: %d\n",floats_read);
    if(floats_read == floats_to_read) {
      printf("SUCCESS\n");
    } else {
      printf("%d floats read. Should have read %d\n",
	     floats_read,floats_to_read);
      exit(8);
    }
    
  endClock = times(NULL);
  endClock -= startClock;
  endSecs = ((float)endClock)/ticks_per_sec;  
  printf("%.3f sec for agrib.x\n",endSecs);
  if(istatus != 0) {
    printf("problem with agrib.c. status = %d\n",istatus);
    exit(istatus);
  }
  printf("alat1 %f, elon1 %f, dx %f, elonv %f,alattan %f\n",
	 alat1,elon1,dx,elonv,alattan);

  /* loop over sites */
  for(i=0;i<n_stations;i++) {
    sp = sta[i];
    if(i < 0) {
      printf("here 8 %d ",i);
      printstation(sp);
    }
    alat = sp->lat;
    elon = sp->lon;
    /* get the appropriate i,j */
    if(elon1 == 0) {
      /* rotated LL coords */
      rotLL_geo_to_ij(alat,elon,lat_0_deg,lon_0_deg,
		      lat_g_SW_deg,lon_g_SW_deg,dxLL,
		      &yreal,&xreal);
    } else {
      w3fb11(alat,elon,alat1,elon1,dx,elonv,alattan,&xreal,&yreal);
    }
    /* get x,y point */
    xi = (int)xreal;
    yj = (int)yreal;
    if(xi < 0 || xi > nx-2 ||
       yj < 0 || yj > ny-2) {
      if(n_out < 10 && DEBUG > 0) {
	printf("out of domain. Setting sta_id to -1 (showing first 10): ");
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
   
    for(field_index=0;field_index<n_g2_fields;field_index++) {
      /* 31 Jan 2008 -- changed x00 etc from int to real!! */
      x00 = g2[xi  + nx*(yj  + ny*field_index)];
      x01 = g2[xi  + nx*(yj1 + ny*field_index)];
      x10 = g2[xi1 + nx*(yj  + ny*field_index)];
      x11 = g2[xi1 + nx*(yj1 + ny*field_index)];
      if(x00 > 9998 || x01 > 9998 || x10 > 9998 || x11 > 9998) {
	/*
	printf("\nAborting station: %d, time: %d, lat %.2f, lon %.2f, xi %.2f, yj %.2f\n",
	       sp->sta_id,sp->obs_time,sp->lat,sp->lon,xreal,yreal);
	printf("index %d, x00: %.2f, x01: %.2f, x10: %.2f, x11: %.2f\n",
	       field_index,x00,x01,x10,x11);
	*/
	sp->sta_id = -1;	/* turn off further processing */
	continue;
      }
      
      interp_value[field_index] =
	(rem_x  ) * (rem_y  ) * x11 +
	(rem_x  ) * (1-rem_y) * x10 +
	(1-rem_x) * (rem_y  ) * x01 +
	(1-rem_x) * (1-rem_y) * x00;

      if(sp->sta_id == 1365 &&
	 (field_index == 0 || field_index == 1)) {
	printf("\nid: %d, time: %d, lat %.2f, lon %.2f, xi %.2f, yj %.2f\n",
	       sp->sta_id,sp->obs_time,sp->lat,sp->lon,xreal,yreal);
	printf("index %d, x00: %.2f, x01: %.2f, x10: %.2f, x11: %.2f, interp: %.2f\n",
	       field_index,x00,x01,x10,x11,interp_value[field_index]);
      }
    }
    Td = (interp_value[0]-273.15)*9/5 + 32;	/* Farenheit */
    T = (interp_value[1]-273.15)*9/5 + 32;	/* Farenheit */
    sp->temp_bilin = T;
    sp->dew_bilin = Td;
    sp->pr_bilin = 0;
    sp->rh_bilin = 0;
    sp->windSpd_bilin = 0;
    sp->windDir_bilin = 0;
    sp->temp_land = 0;
    sp->dew_land = 0;
    sp->pr_land = 0;
    sp->rh_land = 0;
    sp->windSpd_land = 0;
    sp->windDir_land = 0;
    sp->temp_water = 0;
    sp->dew_water = 0;
    sp->pr_water = 0;
    sp->rh_water = 0;
    sp->windSpd_water = 0;
    sp->windDir_water = 0;
    
    if(0) {
      /* get wind in mph, and direction */
      ws = (float)sqrt((double)(U*U + V*V));
      sp->windSpd_bilin = ws / 0.447 + 0.5 ;
      radians=atan2(U,V);
      /* rotate direction appropriately for the RUC grid */
      /* this means that S winds near the E coast need to pick up
	 an W component wrt true N.  So rotate the wind vectors
	 clockwise (+) near the E coast.
      */
      if(alattan != 0) {
	rotcon = sin(alattan*deg_to_radians);
	dlon = elonv - elon;
	while(dlon > 180) {dlon -= 360;}
	while (dlon < -180) {dlon += 360;}
	theta = - rotcon*(dlon);
      } else {
	/* rotated LL grid */
	theta = rotLL_wind2true_deg(alat,elon,lat_0_deg,lon_0_deg);
      }
      wd=(long)(radians*57.2958 + theta + 180. + 0.5);
      if(wd > 360) wd -= 360;
      if(wd < 0) wd += 360;
      sp->windDir_bilin = wd;
      if(0 && sp->sta_id == 81) {
	printf("model U: %.2f, V: %.2f, spd (m/s): %.2f, wd: %d, theta: %.0f\n",
	       U,V,ws,wd,theta);
      }
    
    /* if not all points have the same land/wat value, get values for
    *  nearest land AND water gridpoints */
    r_min_land = 1e20;
    i_min_land = -1;
    j_min_land = -1;
    r_min_wat = 1e20;
    i_min_wat = -1;
    j_min_wat = -1;
    some_land_wat_dif=0;
    for(jn=0;jn<2;jn++) {
      for(in=0;in<2;in++) {
	if(gsoil[xi+in  + nx*(yj+jn)]  != sp->land_wat) {
	  /* not same land_water type */
	  some_land_wat_dif++;
	}
	if(gsoil[xi+in  + nx*(yj+jn)] == 1) {
	  /*land*/
	    r = sqrt(pow(xreal - (xi+in),2) +
		     pow(yreal - (yj+jn),2));
	    /* debugging
	       bearing = atan2(xi+in - xreal,yj+jn - yreal)*57.3;
	       printf("i %d, j %d, r %.2f, bearing %f\n",
	       in,jn,r,bearing); */
	    if(r < r_min_land) {
	      r_min_land = r;
	      i_min_land = in;
	      j_min_land = jn;
	    }
	} else {
	  /* water */
	  r = sqrt(pow(xreal - (xi+in),2) +
		   pow(yreal - (yj+jn),2));
	  if(r < r_min_wat) {
	    r_min_wat = r;
	    i_min_wat = in;
	    j_min_wat = jn;
	  }
	}
      }
    }
    sp->ndiff = some_land_wat_dif;
    
    if(i_min_land >= 0) {
      /* land nearest neighbor */
      sp->r_land = r_min_land;
      sp->bearing_land = atan2(xi+i_min_land - xreal,yj+j_min_land - yreal)*57.3;
      /* put in range 0-360 */
      if(sp->bearing_land < 0) {
	sp->bearing_land += 360.;
      }
      sp->pr_land = g2[xi+i_min_land  + nx*(yj+j_min_land  + ny*0)]/100.;
      sp->dew_land = (g2[xi+i_min_land   + nx*(yj+j_min_land   + ny*1)]-273.15)*9/5 + 32;
      sp->temp_land = (g2[xi+i_min_land   + nx*(yj+j_min_land   + ny*4)]-273.15)*9/5 + 32;
      sp->rh_land = g2[xi+i_min_land   + nx*(yj+j_min_land   + ny*5)];
      U = g2[xi+i_min_land   + nx*(yj+j_min_land   + ny*2)];
      V= g2[xi+i_min_land   + nx*(yj+j_min_land   + ny*3)];
      /* get wind in mph, and direction */
      sp->windSpd_land = (float)sqrt((double)(U*U +V*V)) / 0.447 + 0.5 ;
      radians=atan2(U,V);
      /* rotate direction appropriately for the RUC grid */
      /* this means that S winds near the E coast need to pick up
	 an W component wrt true N.  So rotate the wind vectors
	 clockwise (+) near the E coast.
      */
      if(alattan != 0) {
	theta = - sin(alattan)*(elonv - elon);
      } else {
	/* rotated LL grid */
	theta = rotLL_wind2true_deg(alat,elon,lat_0_deg,lon_0_deg);
	/*
	if(i_min_wat > 0) {
	  printf("Station %d. land: %.2f %.2f %.2f %.2f wds = %.0f %.0f %.0f\n",
		 sp->sta_id,alat,elon,xreal,yreal,theta);
	}
	*/
      }
      wd=(long)(radians*57.2958 + theta + 180. + 0.5);
      if(wd > 360) wd -= 360;
      if(wd < 0) wd += 360;
      sp->windDir_land = wd;
    } else {
      sp->r_land = -1;
    }
    if(i_min_wat >= 0) {
      /* nearest water neighbor */
      sp->r_water = r_min_wat;
      sp->bearing_water = atan2(xi+i_min_wat - xreal,yj+j_min_wat - yreal)*57.3;
      /* put in range 0-360 */
      if(sp->bearing_water < 0) {
	sp->bearing_water += 360.;
      }
      sp->pr_water = g2[xi+i_min_wat  + nx*(yj+j_min_wat   + ny*0)]/100.;
      sp->dew_water = (g2[xi+i_min_wat   + nx*(yj+j_min_wat   + ny*1)]-273.15)*9/5 + 32;
      sp->temp_water = (g2[xi+i_min_wat   + nx*(yj+j_min_wat   + ny*4)]-273.15)*9/5 + 32;
      sp->rh_water = g2[xi+i_min_wat   + nx*(yj+j_min_wat   + ny*5)];
      U = g2[xi+i_min_wat   + nx*(yj+j_min_wat   + ny*2)];
      V= g2[xi+i_min_wat   + nx*(yj+j_min_wat   + ny*3)];
      /* get wind in mph, and direction */
      sp->windSpd_water = (float)sqrt((double)(U*U +V*V)) / 0.447 + 0.5 ;
      radians=atan2(U,V);
      /* rotate direction appropriately for the RUC grid */
      /* this means that S winds near the E coast need to pick up
	 an W component wrt true N.  So rotate the wind vectors
	 clockwise (+) near the E coast.
      */
      if(alattan != 0) {
	theta = - sin(alattan)*(elonv - elon);
      } else {
	/* rotated LL grid */
	theta = rotLL_wind2true_deg(alat,elon,lat_0_deg,lon_0_deg);
	/*
	if(i_min_land > 0) {
	  printf("Station %d. water: %.2f %.2f %.2f %.2f theta = %f\n",
		 sp->sta_id,alat,elon,xreal,yreal,theta);
		 }
	*/
      }
      wd=(long)(radians*57.2958 + theta + 180. + 0.5);
      if(wd > 360) wd -= 360;
      if(wd < 0) wd += 360;
      sp->windDir_water = wd;
    }  else {
      sp->r_water = -1;
    }
    if(i < 0) {
      printf("here 9a %d ",i);
      printstation(sp);
    }
    if(sp->ndiff >0 && i_diff< 20) {
      i_diff++;
      printf("ndiff > 0 %d ",i);
      printstation(sp);
    }
    }
  }
  printf("%d stations out of domain\n",
	 n_out);
}
