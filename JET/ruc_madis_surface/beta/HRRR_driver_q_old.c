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
  MYSQL  *conn;
  char *filename;
  char *tmp_file;
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
  char *nets;
  char *station_file;
  int nx;
  int ny;
  int nz;
  int rh_flag;			/* 0 for rh variable = RH, 1 for rh variable = SPFH */
  float alat1,elon1, dx,elonv,alattan;
  int arg_i=0;
  int DEBUG = 2;
  int n_stations;
  STATION *STATIONS[MAX_STATIONS];
  FILE *mail = NULL;		/* stream for notification of missing input */
  char mailFile[80];
  int grib_type;

  /* prototypes */
  time_t makeSecs(int year, int julday, int hour);
  int get_stations_q(STATION *sta[],MYSQL *conn,time_t valid_secs,
		     char *nets,int DEBUG);
  void fill_surface_values_q(STATION *sta[],int n_stations,
			     char *filename,char *tmp_file, int grib_type,int nx, int ny,int nz,
			     float alat1,float elon1, float dx,
			     float elonv,float alattan,
			     int rh_flag, int DEBUG);
  void fill_GLMP_surface_values(STATION *sta[],int n_stations,
			     char *filename,char *tmp_file, int grib_type,int nx, int ny,int nz,
			     float alat1,float elon1, float dx,
			     float elonv,float alattan,
			     int rh_flag, int DEBUG);
   void write_stations5q(STATION *sta[],int n_stations,
			MYSQL *conn,
			char *model,time_t valid_secs,
			int fcst_proj,
			char *data_file,char *data_1f_file,
			char *coastal_file,char *coastal_station_file,
			int DEBUG);
   void printstation(STATION *s);
  
  if(argc < 13) {
    printf("Usage: HRRR_driver_q.x nets model valid_time filename fcst_len "
	   "alat1 elon1 elonv alattan dx nx ny nz data_file data_1f_file coastal_file "
	   "coastal_station_file rh_flag [DEBUG]\n");
    exit(1);
  }

  arg_i=1;
  nets = argv[arg_i++];
  model = argv[arg_i++];
  (void)sscanf(argv[arg_i++],"%ld",&valid_secs);
  filename = argv[arg_i++];
  tmp_file = argv[arg_i++];
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
  data_file = argv[arg_i++];
  data_1f_file = argv[arg_i++];
  coastal_file = argv[arg_i++];
  coastal_station_file = argv[arg_i++];
  (void)sscanf(argv[arg_i++],"%i",&rh_flag);
  if(argc >= arg_i) {
    (void)sscanf(argv[arg_i++],"%i",&DEBUG);
  }
  printf("got here with DEBUG = %d\n",DEBUG);
  printf("Xue %d argc loaded for %d network(s)\n",argc,arg_i);
  printf("Xue %d nz for %d \n",nz);
  exit(0);


  /* set up mysql connection */
  conn = do_connect("wolphin.fsl.noaa.gov",getenv("DBI_USER"),getenv("DBI_PASS"),
		    "madis3",0,(void *)NULL,0);

  if(conn == NULL) {
    fprintf(stderr,"Connection to database FAILED!\n");
    exit(1);
  }
  n_stations = get_stations_q(STATIONS,conn,valid_secs,nets,DEBUG);
  printf("%d stations loaded for %s network(s)\n",n_stations,nets);

  if(n_stations > 0) {
    if(strncmp(model,"GLMP",4) == 0) {
      fill_GLMP_surface_values(STATIONS,n_stations,filename,tmp_file,grib_type,
			       nx,ny,nz,alat1,elon1,dx,elonv,alattan,rh_flag,DEBUG);
    } else {
      fill_surface_values_q(STATIONS,n_stations,filename,tmp_file,grib_type,
			    nx,ny,nz,alat1,elon1,dx,elonv,alattan,rh_flag,DEBUG);
    }
    write_stations5q(STATIONS,n_stations,conn,model,valid_secs,fcst_len,
		     data_file,data_1f_file,coastal_file,
		     coastal_station_file,DEBUG);
  }
  do_disconnect(conn);
  /*return(n_stations);*/
  exit(0);
}
