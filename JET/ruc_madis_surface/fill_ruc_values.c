#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>
#include <math.h>
#include <unistd.h>
#include "stations.h"

void fill_ruc_values(char *model,int grib_type,STATION *sta[],int n_stations,
		     char *filename,int nx, int ny,int nz,
		     float alat1,float elon1, float dx,
		     float elonv,float alattan,int DEBUG) {
  FILE *inFile;
  STATION *sp;
  int i,j,xi,yj,xi1,yj1;
  float x00,x01,x10,x11;
  int field_index;
  float xreal,yreal,rem_x,rem_y;
  float interp_value[5];
  float SLP,Td,U,V,T;
  int g3_fields[] = {};
  int n_g3_fields = 0;
  char out_filename[80];
  char cmd[500];
  /* SLP, DPT, U, V, T */
  int g2_fields[] = {129,17,33,34,11};
  int n_g2_fields = 5;
  int no_column = -1;
  int istatus=0;
  time_t startClock;
  time_t endClock;
  float endSecs;
  long int ticks_per_sec;
  float alat,elon;
  float rotcon = 0.4226183;	/* sine of 25 degrees */
  float theta;			/* degrees to rotate winds from RUC coords */
  float radians;
  long wd;
  int n_out=0;
  float r_min_land,r,bearing_land;
  float r_min_wat,bearing_wat;
  int i_min_land,j_min_land,in,jn,some_land_wat_dif;
  int i_min_wat,j_min_wat;
  int i_diff = 0;
  
  float *g3; 
  float *g2;
  int *gsoil;			/* =1 for land, = -1 for water */

  void w3fb11(float alat,float elon,
	    float alat1,float elon1,float dx,float elonv,float alatan,
	    float *pxi,float *pxj);
  void w3fb12(float xi,float xj,float alat1,float elon1,
	    float dx,float elonv,float alatan,
	    float *alat,float *elon);
  int agrib_(int *nz_ptr, int *n_g3_fields,int *g3_fields,
	     int *n_g2_fields,int *g2_fields,
	     float *G3, float *G2,int *i_column,int *j_column,
	     char *filename, int *istatus_ptr );
  void read_soil_file(int *gsoil);

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

  gsoil = (int *)malloc(sizeof(int)*nx*ny);
  if(gsoil == NULL) {
    printf("not enough space for gsoil\n");
    exit(1);
  }

  read_soil_file(gsoil);
  /* for debugging
  for(j=ny-1;j>=0;j=j-2) {
    for(i=0;i<nx;i=i+2) {
      if(gsoil[i  + nx*j] == -1) {
	printf(".");
      } else {
	printf("+");
      }
    }
    printf("\n");
    }
   */
  ticks_per_sec = sysconf(_SC_CLK_TCK);
  startClock = times(NULL);

  /* */
  if(grib_type == 1) {
    printf("reading grib1 file %s\n",filename);
    agrib_(&nz,&n_g3_fields,g3_fields,
	   &n_g2_fields,g2_fields,
	   g3,g2,
	   &no_column,&no_column,
	   filename,&istatus);
  } else {
    printf("reading grib2 file %s\n",filename);
    snprintf(out_filename,80,"tmp/Op13.%d.tmp",getpid());
    snprintf(cmd,500,
	     "./wgrib2.x %s|./get_RUC_grib2_fields.pl|"
	     "./wgrib2.x -order raw -i -no_header -bin %s %s",
	     filename,out_filename,filename);
    printf("command is %s\n",cmd);
    if(system(cmd) != 0) {
      printf("error in command!\n");
      exit(1);
    }
    /* now read the resulting file */
    if(!(inFile = fopen(out_filename, "r"))) {
      printf("could not read file\n");
      exit(1);
    }
    fread(g2,sizeof(float),n_g2_fields*nx*ny,inFile);
    fclose(inFile);
    snprintf(cmd,500,"/bin/rm %s",out_filename);
    if(system(cmd) != 0) {
      printf("'%s' FAILED\n");
      exit(1);
    }
  }
  endClock = times(NULL);
  endClock -= startClock;
  endSecs = ((float)endClock)/ticks_per_sec;  
  printf("%.3f sec to read file\n",endSecs);

  printf("alat1 %f, elon1 %f, dx %f, elonv %f,alattan %f\n",
	 alat1,elon1,dx,elonv,alattan);

  /* loop over sites */
  for(i=0;i<n_stations;i++) {
    sp = sta[i];
    alat = sp->lat;
    elon = sp->lon;
    /* get the appropriate i,j */
    w3fb11(alat,elon,alat1,elon1,dx,elonv,alattan,&xreal,&yreal);
    /* */
    /* get x,y point */
    xi = (int)xreal;
    yj = (int)yreal;
    if(xi < 0 || xi > nx-2 ||
       yj < 0 || yj > ny-2) {
      if(DEBUG > 1) {
	printf("out of domain: ");
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
    if(sp->sta_id == 1494) {
      printf("STA 1494: yreal %f, yj %d, rem_y %f\n",
	     yreal,yj,rem_y);
    }
    
    for(field_index=0;field_index<5;field_index++) {
      /* 31 Jan 2008 -- changed x00 etc from int to real!! */
      x00 = g2[xi  + nx*(yj  + ny*field_index)];
      x01 = g2[xi  + nx*(yj1 + ny*field_index)];
      x10 = g2[xi1 + nx*(yj  + ny*field_index)];
      x11 = g2[xi1 + nx*(yj1 + ny*field_index)];
      
      interp_value[field_index] =
	(rem_x  ) * (rem_y  ) * x11 +
	(rem_x  ) * (1-rem_y) * x10 +
	(1-rem_x) * (rem_y  ) * x01 +
	(1-rem_x) * (1-rem_y) * x00;
    }
    SLP = interp_value[0]/100.;	/* Pascals -> millibars */
    Td = (interp_value[1]-273.15)*9/5 + 32;	/* Farenheit */
    U   = interp_value[2];		/* m/s */
    V   = interp_value[3];		/* m/s */
    T = (interp_value[4]-273.15)*9/5 + 32;	/* Farenheit */
    sp->pr_bilin = SLP;
    sp->temp_bilin = T;
    sp->dew_bilin = Td;
    /* get wind in mph, and direction */
    sp->windSpd_bilin = (float)sqrt((double)(U*U + V*V)) / 0.447 + 0.5 ;
    radians=atan2(U,V);
    /* rotate direction appropriately for the RUC grid */
    /* this means that S winds near the E coast need to pick up
       an W component wrt true N.  So rotate the wind vectors
       clockwise (+) near the E coast.
    */
    theta = - rotcon*(-95.0 - elon);
    wd=(long)(radians*57.2958 + theta + 180. + 0.5);
    if(wd > 360) wd -= 360;
    if(wd < 0) wd += 360;
    sp->windDir_bilin = wd;
    
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
      theta = - rotcon*(-95.0 - elon);
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
      theta = - rotcon*(-95.0 - elon);
      wd=(long)(radians*57.2958 + theta + 180. + 0.5);
      if(wd > 360) wd -= 360;
      if(wd < 0) wd += 360;
      sp->windDir_water = wd;
    }  else {
      sp->r_water = -1;
    }
    if(sp->ndiff >0 && i_diff++ < 20) {
      printstation(sp);
    }
  }
  printf("%d stations out of RUC domain\n",
	 n_out);
}

void read_soil_file(int *gsoil) {
  FILE *fp;
  int nx = 451;
  int ny = 337;
  int i,j;
  float x;
  
  fp = fopen("vegtype_usgs.dat","r");
  if(fp == NULL) {
    printf("could not open soil type file\n");
    exit(1);
  }
  for(j=0;j<ny;j++) {
    for(i=0;i<nx;i++) {
      fscanf(fp,"%f",&x);
      if(x == 16.) {
	 gsoil[i  + nx*j] = -1;
      } else {
	gsoil[i  + nx*j] = 1;
      }
    }
  }
}
  
