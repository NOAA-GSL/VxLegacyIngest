#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <sys/types.h>
#include <mysql.h>
#include "my_mysql_util.h"
#include "ceil_stations.h"

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
  int n_zero_ceils=0;
  STATION *STATIONS[MAX_STATIONS];
  FILE *mail = NULL;		/* stream for notification of missing input */
  char mailFile[80];
  int grib_type;
  int grid_type;
  char *tmp_file;
  char *data_file;


  /* prototypes */
  time_t makeSecs(int year, int julday, int hour);
  int get_stations_retro(STATION *sta[],MYSQL *conn,time_t valid_secs,
		   int DEBUG);
  int fill_rotLL_ceil_values(STATION *sta[],int n_stations,
			      char *filename,int grib_type,int grid_type, char *tmp_file,int DEBUG);
  void write_ceils (STATION *sta[],int n_stations,
		       MYSQL *conn,
		       char *model,time_t valid_secs,
		       int fcst_proj,char *data_file,int DEBUG);

  model = argv[arg_i++];
  (void)sscanf(argv[arg_i++],"%ld",&valid_secs);
  filename = argv[arg_i++];
  (void)sscanf(argv[arg_i++],"%d",&grib_type);
  (void)sscanf(argv[arg_i++],"%d",&grid_type);
  tmp_file = argv[arg_i++];
  data_file = argv[arg_i++];
  (void)sscanf(argv[arg_i++],"%d",&fcst_len);
  (void)sscanf(argv[arg_i++],"%i",&DEBUG);
  
  /* put dx in meters */
  dx *= 1000;

  /* set up mysql connection */
  conn = do_connect("wolphin.fsl.noaa.gov","wcron0_user","cohen_lee",
		    "ceiling2",0,(void *)NULL,0);

  n_stations = get_stations_retro(STATIONS,conn,valid_secs,DEBUG);
  printf("%d stations loaded\n",n_stations);

  if(n_stations > 0) {
    n_zero_ceils = fill_rotLL_ceil_values(STATIONS,n_stations,filename,
					   grib_type,grid_type,tmp_file,DEBUG);
    write_ceils(STATIONS,n_stations,conn,model,valid_secs,fcst_len,data_file,DEBUG);
    if(n_zero_ceils > 100) {
      (void) snprintf(mailFile,80,"/tmp/mailThis.tmp");
      mail=fopen(mailFile,"w+");  
      fprintf(mail,"To: william.r.moninger@noaa.gov\n");
      fprintf(mail,"From: ceiling_processing\n");
      fprintf(mail,"Subject: TOO MANY ZERO CEILINGS FOR %s valid %s\n\n",
	      model, asctime(gmtime(&valid_secs)));
      fprintf(mail,"%d stations with zero ceils for %s %d fcst, valid %s\n",
	      n_zero_ceils, model, fcst_len, asctime(gmtime(&valid_secs)));
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
    n_zero_ceils = -1;
  }
  return(n_zero_ceils);
}

