#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <sys/types.h>
#include <mysql.h>
#include "my_mysql_util.h"
#include "stations.h"

  struct tm tm;
  struct tm *tp;

main (int argc, char *argv[])
{
  char *tmp_file;
  int grib_type;
  MYSQL  *conn;
  char *filename;
  char *data_file;
  char *data_1f_file;
  char *coastal_file;
  char *coastal_station_file;
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
  int DEBUG = 2;
  int n_stations;
  STATION *STATIONS[MAX_STATIONS];
  FILE *mail = NULL;		/* stream for notification of missing input */
  char mailFile[80];
  int max_retro_secs;		/* max time in obs_retro table */


  /* prototypes */
  time_t makeSecs(int year, int julday, int hour);
  int get_stations_retro(STATION *sta[],MYSQL *conn,time_t valid_secs,
			 int max_retro_secs, int DEBUG);
  void fill_surface_values5(STATION *sta[],int n_stations,
			    char *filename,char *tmp_file, int grib_type,int nx, int ny,int nz,
			    float alat1,float elon1, float dx,
			    float elonv,float alattan, int DEBUG);
  void write_stations_files(STATION *sta[],int n_stations,
			   MYSQL *conn,
			   char *model,time_t valid_secs,
			   int fcst_proj,char *data_file,char *data_1f_file,
			   char *coastal_file, char *coastal_station_file,
			   int DEBUG);
  void printstation(STATION *s);
  
  if(argc < 13) {
    printf("Usage: WRF_retro_driver5.x model valid_time filename grib_type fcst_len "
	   "alat1 elon1 elonv alattan dx nx ny nz max_retro_time tmp_file data_file data_1f_file coastal_file "
	   "coastal_station_file [DEBUG]\n");
    exit(1);
  }

  model = argv[arg_i++];
  (void)sscanf(argv[arg_i++],"%ld",&valid_secs);
  filename = argv[arg_i++];
  (void)sscanf(argv[arg_i++],"%d",&grib_type);
  (void)sscanf(argv[arg_i++],"%d",&fcst_len);
  (void)sscanf(argv[arg_i++],"%f",&alat1);
  (void)sscanf(argv[arg_i++],"%f",&elon1);
  (void)sscanf(argv[arg_i++],"%f",&elonv);
  (void)sscanf(argv[arg_i++],"%f",&alattan);
  (void)sscanf(argv[arg_i++],"%f",&dx);
  (void)sscanf(argv[arg_i++],"%i",&nx);
  (void)sscanf(argv[arg_i++],"%i",&ny);
  (void)sscanf(argv[arg_i++],"%i",&nz);
  (void)sscanf(argv[arg_i++],"%d",&max_retro_secs);
  tmp_file = argv[arg_i++];
  data_file = argv[arg_i++];
  data_1f_file = argv[arg_i++];
  coastal_file = argv[arg_i++];
  coastal_station_file = argv[arg_i++];
  if(argc >= arg_i) {
    (void)sscanf(argv[arg_i++],"%i",&DEBUG);
  }
  printf("got here with DEBUG = %d and dx = %d\n",DEBUG,dx);

  /* set up mysql connection */
  conn = do_connect("wolphin.fsl.noaa.gov",getenv("DBI_USER"),getenv("DBI_PASS"),
		    "madis3",0,(void *)NULL,0);

  if(conn == NULL) {
    fprintf(stderr,"Connection to database FAILED!\n");
    exit(1);
  }
  n_stations = get_stations_retro(STATIONS,conn,valid_secs,max_retro_secs,DEBUG);
  printf("%d stations loaded\n",n_stations);
  if(n_stations > 0) {
    fill_surface_values5(STATIONS,n_stations,filename,tmp_file,grib_type,
			 nx,ny,nz,alat1,elon1,dx,elonv,alattan,DEBUG);
    write_stations_files(STATIONS,n_stations,conn,model,valid_secs,fcst_len,
		       data_file,data_1f_file,coastal_file,coastal_station_file,DEBUG);
  }
  do_disconnect(conn);
  /*return(n_stations);*/
  exit(0);
}
