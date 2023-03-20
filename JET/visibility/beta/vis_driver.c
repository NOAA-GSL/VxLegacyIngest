#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <sys/types.h>
#include <mysql.h>
#include "my_mysql_util.h"
#include "vis_stations.h"

  struct tm tm;
  struct tm *tp;

main (int argc, char *argv[])
{
  MYSQL  *conn;
  char *filename,*tmp_file;
  char month_name[4];
  char line[400];
  /* pressure now in tenths of mbs */
  long mand_level[] = {10000,9250,8500,7000,5000,4000,3000,2500,1500,1000};
  char *ptr;			/* pointer to parts of the input filename */
  int year,month,mday,jday,hour,fcst_len;
  int i;
  time_t valid_secs;
  char *model;
  char *station_file;
  int nx;
  int ny;
  int nz;
  float alat1,elon1, dx,elonv,alattan;
  int arg_i=1;
  int DEBUG = 0;
  int n_stations;
  int grib_type,grid_type;
  int trouble = 0;
  STATION *STATIONS[MAX_STATIONS];


  /* prototypes */
  time_t makeSecs(int year, int julday, int hour);
  int get_vis_stations(STATION *sta[],MYSQL *conn,time_t valid_secs,
		   int DEBUG);
  void fill_vis_values(STATION *sta[],int n_stations,
		       char *filename,int grib_type, int grid_type,char *tmp_file,int nx, int ny,int nz,
		       float alat1,float elon1, float dx,
			float elonv,float alattan,int DEBUG);
  void write_vis (STATION *sta[],int n_stations,
		       MYSQL *conn,
		       char *model,time_t valid_secs,
		       int fcst_proj,int DEBUG);
  if(argc < 13) {
    printf("Usage: vis.x model valid_time filename grib_type grid_type tmp_file fcst_len"
	   "alat1 elon1 elonv alattan dx nx ny nz [DEBUG]\n");
    exit(1);
  }

  model = argv[arg_i++];
  (void)sscanf(argv[arg_i++],"%ld",&valid_secs);
  filename = argv[arg_i++];
  (void)sscanf(argv[arg_i++],"%i",&grib_type);
  (void)sscanf(argv[arg_i++],"%i",&grid_type);
  tmp_file = argv[arg_i++];
  (void)sscanf(argv[arg_i++],"%d",&fcst_len);
  (void)sscanf(argv[arg_i++],"%f",&alat1);
  (void)sscanf(argv[arg_i++],"%f",&elon1);
  (void)sscanf(argv[arg_i++],"%f",&elonv);
  (void)sscanf(argv[arg_i++],"%f",&alattan);
  (void)sscanf(argv[arg_i++],"%f",&dx);
  (void)sscanf(argv[arg_i++],"%i",&nx);
  (void)sscanf(argv[arg_i++],"%i",&ny);
  (void)sscanf(argv[arg_i++],"%i",&nz);
  if(argc >= 15) {
    (void)sscanf(argv[arg_i++],"%i",&DEBUG);
  }
  
  /* put dx in meters */
  dx *= 1000;

  printf("valid secs is %ld\n",valid_secs);
  
  /* set up mysql connection */
  conn = do_connect(getenv("DBI_HOST"),getenv("DBI_USER"),getenv("DBI_PASS"),
		    getenv("DBI_DB"),0,(void *)NULL,0);
  printf("connected to database %s\n",getenv("DBI_DB"));

  n_stations = get_vis_stations(STATIONS,conn,valid_secs,DEBUG);
  printf("%d stations loaded\n",n_stations);

  /*
  for(i=0;i<n_stations;i++) {
      printstation(STATIONS[i]);
  }
  */
  if(n_stations > 0) {
    fill_vis_values(STATIONS,n_stations,filename,grib_type,grid_type,tmp_file,
		     nx,ny,nz,alat1,elon1,dx,elonv,alattan,DEBUG);
    write_vis(STATIONS,n_stations,conn,model,valid_secs,fcst_len,DEBUG);
  } else {
    trouble = 3;
  }
  return(trouble);			/* keep lint happy (main defined to return int */
}

