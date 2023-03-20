#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>
#include <math.h>
#include <float.h>
#include <time.h>
#include <unistd.h>


/**int agrib2_(int *nz_ptr, int *n_g3_fields,int *g3_fields,
	   int *n_g2_fields,int *g2_fields,
	   float *G3, float *G2,
	   char *filename, int *istatus_ptr ) {
* fortran- and C-callable grib2 reader
*
* input arguments
*
* nz_ptr - pointer to number of z levels (can be less than what's in
*          the grib file
* n_g3_fields - pointer to the number of 3d (hybrid lev or pressure)
*               fields to be returned
* g3_fields - pointer to an array of integers, *n_g3_fields in size,
*             that has the numerical ID's of the 3d variables desired,
*             as they appear in struct ParmTable parm_table_ncep_opn
*             below.
* n_g2_fields - pointer to the number of 2d (sfc) fields to be returned.
* g2_fields - pointer to an array of integers, *n_g2_fields in size
*             that has the numerical ID's of the 3d variables desired,
*             as they appear in struct ParmTable parm_table_ncep_opn
*             below.
*
* output arguments:
*
* g2 - an array big enough to hold the surface values for the 2d fields
*      requested.  If startx = -1, g2 must hold nx*ny*n_g2_fields; if
*      startx = a positive integer, g2 must hold 1*1*n_g2_fields.
* g3 - an array big enough to hold nz hybrid lev values for the 3d
*      fields requested.  If startx = -1, g3 must hold nx*ny*nz*g3_fields;
*      if startx = a positive integer, g3 must hold 1*1*nz*n_g3_fields.
*
* example usage
* C:
  int nx = 301;
  int ny = 225;
  int nz = 50;

  int g3_fields[] = {1,7,189,53,33,34};
  int n_g3_fields = 6;
  int g2_fields[] = {157,156};
  int n_g2_fields = 2;
  
  float g3[n_g3_fields][nz][ny][nx]; 
  float g2[n_g2_fields][ny][nx];
  int istatus=0;

  result = agrib2_(&nz,&n_g3_fields,g3_fields,
		  &n_g2_fields,g2_fields,
		  &g3[0][0][0][0],&g2[0][0][0],
		  filename,&istatus);

* FORTRAN
      parameter(nx40=151,ny40=113)
      parameter(nlev=37)
      parameter(n_g3_fields = 5)
      integer g3_fields(n_g3_fields)
      data g3_fields/7,11,52,33,34/
      real g3(nx40,ny40,nlev,n_g3_fields) 
      parameter(n_g2_fields = 1)
      integer g2_fields(n_g2_fields)
      data g2_fields/1/
      real g2(nx40,ny40,n_g2_fields)
      inteter ret,istatus
      ...
      ret = agrib(nx40,ny40,nlev,n_g3_fields,g3_fields,
     * n_g2_fields,g2_fields,g3,g2,
     * grib_file,istatus)
*/

int agrib2_(int *nx_ptr,int *ny_ptr,int *nz_ptr, int *n_g3_fields,int *g3_fields,
	   int *n_g2_fields,int *g2_fields,
	   float *g3, float *g2,
	   char *filename, int *istatus_ptr ) {

  FILE *input = NULL;
  char line[400];
  time_t startClock;
  time_t endClock;
  float endSecs;
  long int ticks_per_sec;
  char out_filename[200];
  int floats_read=0;
  int floats_to_read=0;
  int nx;
  int ny;
  int nz;
  int result;
 
  ticks_per_sec = sysconf(_SC_CLK_TCK);
  startClock = times(NULL);
  nx = *nx_ptr;
  ny = *ny_ptr;
  nz = *nz_ptr;

  snprintf(out_filename,200,"tmp2/%d_grib2_dump.txt",getpid());
  printf("out_filename is |%s|\n",out_filename);
  snprintf(line,500,"./make_grib2_iso_tmp_file.pl %s %s 0",
	   filename,out_filename);
  printf("command is %s\n",line);
  system(line);
  printf("finished dumping grib file\n");
  /* now read the dump file. */
  if ((input = fopen(out_filename,"r")) == NULL) {
    fprintf(stderr,"could not open file: %s\n", out_filename);
    exit(7);
  }
  floats_to_read = *n_g3_fields*nx*ny*nz + *n_g2_fields*nx*ny;
  floats_read = fread(g3,sizeof(float),*n_g3_fields*nx*ny*nz,input);
  floats_read += fread(g2,sizeof(float),*n_g2_fields*nx*ny,input);
  if(floats_read == floats_to_read) {
    printf("SUCCESS loading grib2 data\n");
  } else {
    printf("%d floats read. Should have read %d\n",
	   floats_read,floats_to_read);
    exit(8);
  }

  fclose(input);
  result = unlink(out_filename);
  if(result == -1) {
    printf("could not unlink %s\n",out_filename);
  }
  endClock = times(NULL);
  endClock -= startClock;
  endSecs = ((float)endClock)/ticks_per_sec;  
  printf("%.3f sec to read grib file\n",endSecs);
}
 
