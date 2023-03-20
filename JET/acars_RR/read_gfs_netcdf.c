/* reads a GFS netCDF file and puts data out in a 3d array
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>

#include "netcdf.h"

typedef struct raob_data_struct {
  long fr,pr,ht,tmp,dp,wd,ws;
} raob_data_struct;

#define MISSING 99999
#define MAX_LEVELS 200

/* hardwired:
   G3[0][nz][ny][nx] = Z (geopotential height)
   G3[1][nz][ny][nx] = T
   G3[2][nz][ny][nx] = RH
   G3[3][nz][ny][nx] = U
   G3[4][nz][ny][nx] = V
*/

int read_gfs_netcdf_(char *filename, float *G3, int *P, char *fcst_date)
{
  int year,month,mday,jday,hour;
  time_t valid_secs;
  struct tm tm;
  struct tm *tp;
  char month_name[4];
  int result;			/* stores return code for reads */
  int bin_data;			/* file descriptor for output data */
  long start[]={0,0,0,0,0};
  long count[]={1,1,1,1,1};
  long stride[]={1,1,1,1,1};
  float buffer[MAX_LEVELS];
  char *fieldname;
  long nx,ny,nz,data_dim_values[5];
  int nc_id,x_id,y_id,z_id,n_recs,Z_id,T_id;
  int data_id,data_ndims,data_dimids[5];
  nc_type data_type;
  int i,j,tot_len,bytes_per_item,startx,starty;
  int icount;			/* counts output levels */
  int done;
  long last_pressure;
  long pr,ws,wd,pr_next,t10_next,td10_next,ws_next,wd_next;
  long t10,td10;
  float fact;
  int p_levels;
  float xcart,ycart;
  float delta_east,delta_north;
  double radians;
  double valTimeD;		/* valid time */
  long valTime;
  float alat,elon,alat1,elon1,dx,elonv,alattan;
  float alat1_file,elon1_file,dx_file,elonv_file,alattan_file;
  char line[80];
  char line2[80];
  int  station_elev;		/* meters */
  char station_name[30];
  int station_id;
  float grid_lat,grid_lon;
  float rotcon ;
  float theta;			/* degrees to rotate winds from RUC coords */
  float ddeg ;			/* grid spacing in degrees  */
  int p_level=0;
  
  
  /* prototypes */
  long my_dir_interp(float fact,long x0, long x1);
  void get_ij(float alat,float elon, float ddeg, float *pxi,float *pxj);
  void get_ll(float startx,float starty,float ddeg, float *grid_lat,float *grid_lon);
  long round(float arg);	/* prototype */

  printf("fcst_date is |%s|\n",fcst_date);
  printf("filename is |%s|\n",filename);
  ncopts=NC_VERBOSE;			/* don't die on read errors */
  nc_id=ncopen(filename,NC_NOWRITE);
  if(nc_id == -1) {
    fprintf(stderr,"!!No data found for %s\n",filename);
    exit(2);
  }
  printf("opening file %s\n",filename);

  /* now read the  file. */
  /* find the values of each dimension */
  fieldname="T";
  data_id = ncvarid(nc_id,fieldname); 
  ncvarinq(nc_id,data_id,(char *) 0, &data_type, &data_ndims,
	   data_dimids, (int *) 0);
  
  for (i=0;i<data_ndims;i++) {
    ncdiminq(nc_id,data_dimids[i],(char *) 0,&data_dim_values[i]);
    printf("%d: dimension %d has value %d\n",i,data_dimids[i],
	   data_dim_values[i]);
  }

  /* read 1D data */
  p_levels = data_dim_values[1];

  count[0] = p_levels;
  data_id=ncvarid(nc_id,"isoLevel");
  ncvarget(nc_id,data_id,start,count,(void *)P);
  
  count[0] = 1;
  nz = p_levels;
  count[1] = nz;
  ny = data_dim_values[2];
  count[2] = ny;
  nx = data_dim_values[3];
  count[3] = nx;
  /*
  for(p_level=0;p_level<p_levels;p_level++) {
    printf("%d %d\n",p_level,P[p_level]);
  }
  */

  /* read 3D data  */
  data_id=ncvarid(nc_id,"GpH");  
  ncvarget(nc_id,data_id,start,count,(void *)&G3[0]);
  data_id=ncvarid(nc_id,"T");
  ncvarget(nc_id,data_id,start,count,(void *)&G3[1*nz*ny*nx]);
  data_id=ncvarid(nc_id,"RH");
  ncvarget(nc_id,data_id,start,count,(void *)&G3[2*nz*ny*nx]);
  data_id=ncvarid(nc_id,"uW");
  ncvarget(nc_id,data_id,start,count,(void *)&G3[3*nz*ny*nx]);
  data_id=ncvarid(nc_id,"vW");
  ncvarget(nc_id,data_id,start,count,(void *)&G3[4*nz*ny*nx]);

  printf("returning from read_gfs_netcdf\n");
  return(0);
}

long round(float arg) {
  long i_arg;
  float dif;

  i_arg = arg;
  dif = arg - i_arg;

  if(dif > 0.5) {
    i_arg++;
  } else if(dif < -0.5) {
    i_arg--;
  }

  return i_arg;
}

/** these two routines not used currently
    
void get_ij(float alat,float elon, float ddeg, float *pxi,float *pxj) {
  if(elon < 0) {
    elon += 360;
  }
  *pxi = elon/ddeg;
  *pxj = (90-alat)/ddeg;
}

void get_ll(float startx,float starty,float ddeg, float *grid_lat,float *grid_lon) {
  *grid_lon = startx*ddeg;
  if(*grid_lon > 180) {
    *grid_lon -=360;
  }
  *grid_lat = 90 - starty*ddeg;
}
*/
  
      
