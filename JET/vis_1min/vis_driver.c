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
  char *filename;
  char month_name[4];
  char line[400];
  /* pressure now in tenths of mbs */
  long mand_level[] = {10000,9250,8500,7000,5000,4000,3000,2500,1500,1000};
  char *ptr;			/* pointer to parts of the input filename */
  int year,month,mday,jday,hour,fcst_len,fcst_min,total_min;
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
  int n_zero_vis=0;
  STATION *STATIONS[MAX_STATIONS];
  FILE *mail = NULL;		/* stream for notification of missing input */
  char mailFile[80];
  int grib_type,grid_type;
  char *tmp_file;
  char *data_file;


  /* prototypes */
  time_t makeSecs(int year, int julday, int hour);
  int get_stations(STATION *sta[],MYSQL *conn,time_t valid_secs,
		   int DEBUG);
  int fill_vis_values(char *model,STATION *sta[],int n_stations,
			char *filename,int total_min,int grib_type,int grid_type,char *tmp_file,
			int nx, int ny,int nz,
			float alat1,float elon1, float dx,
			float elonv,float alattan, int DEBUG);
  void write_vis (STATION *sta[],int n_stations,
		       MYSQL *conn,
		       char *model,time_t valid_secs,
		       int fcst_proj,int fcst_min,int total_min,char *data_file,int DEBUG);
  if(argc < 13) {
    printf("Usage: vis_driver.x model valid_time filename grib_type tmp_file data_file fcst_len fcst_min total_min"
	   "alat1 elon1 elonv alattan dx nx ny nz [DEBUG]\n");
    exit(1);
  }

  model = argv[arg_i++];
  (void)sscanf(argv[arg_i++],"%ld",&valid_secs);
  filename = argv[arg_i++];
  (void)sscanf(argv[arg_i++],"%d",&grib_type);
  (void)sscanf(argv[arg_i++],"%d",&grid_type);
  tmp_file = argv[arg_i++];
  data_file = argv[arg_i++];
  (void)sscanf(argv[arg_i++],"%d",&fcst_len);
  (void)sscanf(argv[arg_i++],"%d",&fcst_min);
  (void)sscanf(argv[arg_i++],"%d",&total_min);
  (void)sscanf(argv[arg_i++],"%f",&alat1);
  (void)sscanf(argv[arg_i++],"%f",&elon1);
  (void)sscanf(argv[arg_i++],"%f",&elonv);
  (void)sscanf(argv[arg_i++],"%f",&alattan);
  (void)sscanf(argv[arg_i++],"%f",&dx);
  (void)sscanf(argv[arg_i++],"%i",&nx);
  (void)sscanf(argv[arg_i++],"%i",&ny);
  (void)sscanf(argv[arg_i++],"%i",&nz);
  if(argc >= 14) {
    (void)sscanf(argv[arg_i++],"%i",&DEBUG);
  }
  
  /* set up mysql connection */
  conn = do_connect("wolphin","wcron0_user","cohen_lee",
		    "vis_1min",0,(void *)NULL,0);

  n_stations = get_stations(STATIONS,conn,valid_secs,DEBUG);
  printf("%d stations loaded\n",n_stations);

  if(n_stations > 0) {
    n_zero_vis = fill_vis_values(model,STATIONS,n_stations,filename,total_min,grib_type,grid_type,tmp_file,
				     nx,ny,nz,alat1,elon1,dx,elonv,alattan,DEBUG);
    if(n_zero_vis < 100) {
      write_vis(STATIONS,n_stations,conn,model,valid_secs,fcst_len,fcst_min,total_min,data_file,DEBUG);
    } else {
      (void) snprintf(mailFile,80,"/tmp/mailThis.tmp");
      mail=fopen(mailFile,"w+");  
      fprintf(mail,"To: william.r.moninger@noaa.gov\n");
      fprintf(mail,"From: vis_1min_processing\n");
      fprintf(mail,"Subject: TOO MANY ZERO VIS FOR %s valid %s\n\n",
	      model, asctime(gmtime(&valid_secs)));
      fprintf(mail,"%d stations with zero vis for %s %d hr %d min fcst, valid %s\nData not loaded to db\n",
	      n_zero_vis, model, fcst_len, fcst_min, asctime(gmtime(&valid_secs)));
      printf(" TOO MANY ZERO VIS FOR %s valid %s\n"
	     "%d stations with zero vis for %d hr %d min fcst, valid %s\n",
	     model, asctime(gmtime(&valid_secs)),
	     n_zero_vis, fcst_len, fcst_min, asctime(gmtime(&valid_secs)));
      fclose(mail);
      (void) snprintf(line,200,"/usr/sbin/sendmail william.r.moninger@noaa.gov " 
		      "< %.80s",mailFile);
      printf("cmd: %s\n",line);
      system(line);
      (void) snprintf(line,200,"/bin/rm %.80s",mailFile);
      printf("cmd: %s\n",line);
      system(line);
    }

  } else {
    n_zero_vis = -1;
  }
  return(n_zero_vis);
}

