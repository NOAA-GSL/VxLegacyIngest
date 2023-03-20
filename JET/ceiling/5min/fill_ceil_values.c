#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>
#include <math.h>
#include <unistd.h>
#include "ceil_stations.h"

int fill_ceil_values(char *model,STATION *sta[],int n_stations,
		      char *filename,int total_min,int grib_type,int grid_type,char *tmp_file,
		      int nx, int ny,int nz,
		      float alat1,float elon1, float dx,
		      float elonv,float alattan,int DEBUG) {
  FILE *input = NULL;
  char line[400];
  int floats_read=0;
  int floats_to_read=0;
  STATION *sp;
  int i,xi,yj,xi1,yj1;
  float x00,x01,x10,x11;
  int field_index;
  int ceil_agl_flag=0;
  int ceil_not_hgt_field=0;
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
   
  float *g3; 
  float *g2;

  void w3fb06(float alat,float elon,
            float alat1,float elon1,float dx,float elonv,
            float *pxi,float *pxj);
  void w3fb11(float alat,float elon,
	    float alat1,float elon1,float dx,float elonv,float alatan,
	    float *pxi,float *pxj);
  void w3fb12(float xi,float xj,float alat1,float elon1,
	    float dx,float elonv,float alatan,
	    float *alat,float *elon);
  void w3fb08(float alat,float elon,
              float alat1,float elon1,float alatan,float dx,
              float *pxi,float *pxj);
  int agrib_ceil(int *nz_ptr, int *n_g3_fields,int *g3_fields,
	     int *n_g2_fields,int *g2_fields,
	     float *G3, float *G2,int *i_column,int *j_column,
	     char *filename, int *istatus_ptr );

  printf("model is %s\n",model);
  printf("grib_type is %d\n",grib_type);
  /* read grib file */
  /* the RR files have 'sfc' and 'cld base' under 'HGT',
     but the RUC files have 'cld base' under 'DIST'
     so correct for the RR files */
  if(ny == 647) {
    /* this is an RR file */
    g2_fields[1] = 7;
    printf("set g2_fields to 7\n");
  }
  
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
    agrib_ceil(&nz,&n_g3_fields,g3_fields,
		 &n_g2_fields,g2_fields,
		 g3,g2,
		 &no_column,&no_column,
		 filename,&istatus);
  } else {
    /* grib2 */
    snprintf(line,500,"./make_grib2_ceil_tmp_file.pl %s %s %d %d",
	     filename,tmp_file,grib_type,total_min);
    printf("command is %s\n",line);
    system(line);
    printf("finished dumping grib file\n");
    /* could return 1 or two fields, depending on whether ceil is agl or msl */
    /* now read the dump file. */
    if ((input = fopen(tmp_file,"r")) == NULL) {
      fprintf(stderr,"could not open file: %s\n", tmp_file);
      exit(7);
    }
    floats_to_read = n_g3_fields*nx*ny*nz + n_g2_fields*nx*ny;
    floats_read = fread(g3,sizeof(float),n_g3_fields*nx*ny*nz,input);
    printf("n_g3_fields read: %d\n",n_g3_fields);
    printf("nx read: %d\n",nx);
    printf("ny read: %d\n",ny);
    printf("nz read: %d\n",nz);
    printf("n_g2_fields read: %d\n",n_g2_fields);
    printf("3d floats read: %d\n",floats_read);
    floats_read += fread(g2,sizeof(float),n_g2_fields*nx*ny,input);
    printf("total floats read: %d\n",floats_read);
    if(floats_read == floats_to_read) {
      printf("SUCCESS with two fields HGT:surface and HGT:ceiling\n");
    } else {
      if(floats_read == floats_to_read/2) {
	printf("SUCCESS with 1 ceiling field\n");
        ceil_not_hgt_field=1;
      }
    }
  }  /* end grib2 processing */
  endClock = times(NULL);
  endClock -= startClock;
  endSecs = ((float)endClock)/ticks_per_sec;  
  /* printf("%.3f sec for agrib_ceil.x\n",endSecs);*/
  if(istatus != 0) {
    printf("problem with agrib_ceil.c. status = %d\n",istatus);
    exit(istatus);
  }
  printf("alat1 %f, elon1 %f, dx %f, elonv %f,alattan %f\n",
	 alat1,elon1,dx,elonv,alattan);

  if(strncmp(model,"RTMA_GSD",8) == 0) {
    printf("ceiling is in AGL. Ignoring HGT:surface field\n");
    ceil_agl_flag = 1;
  }

  /* loop over sites */
  for(i=0;i<n_stations;i++) {
    sp = sta[i];
    alat = sp->lat;
    elon = sp->lon;

    if (grid_type==1){
      /* lambert*/
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
    } 
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
    if(ceil_not_hgt_field == 1) {
      field_index=0; 
      ceil_agl = g2[xi  + nx*(yj  + ny*field_index)];
    } else if(ceil_agl_flag == 1) {
      /* we have two height fields, but the ceiling height field is in AGL */
      ceil_agl = g2[xi  + nx*(yj  + ny*1)];
    } else {
      /* the HGT:cloud cieling field is in MSL, so HGT:surface must be subtracted
          (I wish the modelers could be consistent! */
      ceil_agl = g2[xi  + nx*(yj  + ny*1)] - g2[xi  + nx*(yj  + ny*0)];
    }
    if(ceil_agl < -1000 ||
       ceil_agl > 1e10) {
      ceil_agl = 6000;
    } else if(ceil_agl <= 0) {
      if(DEBUG == 1) {
	printf("negative AGL ceiling for %d: %f %f\n",
	       sp->sta_id,ceil_msl,sfc_hgt);
      }
      ceil_agl = 0;
      n_zero_ceils++;
    } else {
      ceil_agl *= 0.32808; /* m -> tens of ft */
      n_good_ceils++;
    }
    sp->ceil = ceil_agl;
    
  }

  printf("%d stations out of domain\n",
	 n_out);
  printf("%d stations with zero ceilings, %d with finite ceilings\n",
	 n_zero_ceils,n_good_ceils);
  return(n_zero_ceils);
}

