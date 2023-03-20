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
  int grib_type;
  char *model;
  char *db_machine;
  char *db_name;
  char *nets;
  int nx;
  int ny;
  int nz;
  float alat1,elon1, dx,elonv,alattan;
  int arg_i=1;
  int DEBUG = 0;
  int n_stations;
  STATION *STATIONS[MAX_STATIONS];


  /* prototypes */
  void dewpoint(float p, float vpt, float qv, float *pt, float *ptd, float *prh);
  time_t makeSecs(int year, int julday, int hour);
  int get_stations_q(STATION *sta[],MYSQL *conn,time_t valid_secs, char *nets,
		     int DEBUG);
  void fill_ruc_values_q(char *model,int grib_type, STATION *sta[],int n_stations,
		       char *filename,int nx, int ny,int nz,
		       float alat1,float elon1, float dx,
		       float elonv,float alattan, int DEBUG);
  void write_stations5q(STATION *sta[],int n_stations,
			MYSQL *conn,
			char *model,time_t valid_secs,
			int fcst_proj,
			char *data_file,char *data_1f_file,
			char *coastal_file,char *coastal_station_file,
			int DEBUG);
  
  if(argc < 13) {
    printf("Usage: agrib_madis_sites_q.x nets model grib_type valid_time filename fcst_len"
	   "alat1 elon1 elonv alattan dx nx ny nz data_file "
	   "data_1f_file coastal_file coastal_station_file [DEBUG]\n");
    exit(1);
  }

  nets = argv[arg_i++];
  db_machine = argv[arg_i++];
  db_name = argv[arg_i++];
  model = argv[arg_i++];
  (void)sscanf(argv[arg_i++],"%d",&grib_type);
  (void)sscanf(argv[arg_i++],"%ld",&valid_secs);
  filename = argv[arg_i++];
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
  if(argc >= arg_i) {
    (void)sscanf(argv[arg_i++],"%i",&DEBUG);
  }
  printf("got here with DEBUG = %d\n",DEBUG);
  
  /* put dx in meters */
  dx *= 1000;

  printf("valid secs is %ld\n",valid_secs);
  
  /* set up mysql connection */
  conn = do_connect(db_machine,getenv("DBI_USER"),getenv("DBI_PASS"),
		    db_name,0,(void *)NULL,0);
  printf("connected to database %s.%s\n",db_machine,db_name);

  n_stations = get_stations_q(STATIONS,conn,valid_secs,nets,DEBUG);
  printf("%d stations loaded for %s network(s)\n",n_stations,nets);

  if(n_stations > 0) {
    fill_ruc_values_q(model,grib_type,STATIONS,n_stations,filename,
		    nx,ny,nz,alat1,elon1,dx,elonv,alattan,DEBUG);
    write_stations5q(STATIONS,n_stations,conn,model,valid_secs,fcst_len,
		    data_file,data_1f_file,coastal_file,
		    coastal_station_file,DEBUG);
  }
  do_disconnect(conn);
  return 0;			/* keep lint happy (main defined to return int */
}

/**********************************************************************/

void dewpoint(float p, float vpt, float qv, float *pt, float *ptd, float *prh) {
  /* ;;returns dewpoint in kelvin,
     ;; given pressure in pascals, virtual potential temp in kelvin
     ;; and water vapor mixing ratio in g/g
     */

  double esw_pascals,e_pascals,log10_e,dewpoint;
  double exnr,cpd_p,rovcp_p,pol,rh,q;
  double tk,tx,e,exner;

  cpd_p=1004.686;
  rovcp_p=0.285714;		/* R/cp */
  exner = cpd_p*pow((p/100000.),rovcp_p);
  q = qv/(1.+qv);
  tk = vpt*exner/(cpd_p*(1.+0.6078*q));
  
  /* Stan's way of calculating sat vap pressure: 
  tx = tk-273.15;
  pol = 0.99999683       + tx*(-0.90826951e-02 +
      tx*(0.78736169e-04   + tx*(-0.61117958e-06 +
      tx*(0.43884187e-08   + tx*(-0.29883885e-10 +
      tx*(0.21874425e-12   + tx*(-0.17892321e-14 +
      tx*(0.11112018e-16   + tx*(-0.30994571e-19)))))))));
  esw_old_pascals = 6.1078/pow(pol,8.) *100.; 
  */
  
  /* Rex's way of calculating sat vap pressure: */
  /* From Fan and Whiting (1987) as quoted in Fleming (1996): BAMS 77, p
     2229-2242, the saturation vapor pressure is given by: */
  esw_pascals=pow(10.,((10.286*tk - 2148.909)/(tk-35.85)));
  e = p*qv/(0.62197+qv);
  rh = e/esw_pascals;
  
  /*printf("Temp: %f, rh %f Saturation: old,new= %f %f\n",
	 tx,rh,esx,esw_pascals);*/
  
  e_pascals = rh*esw_pascals;
  log10_e = log10(e_pascals);
  
  /* invert the formula for esw to see the temperature at which
     e is the saturation value */
  
  dewpoint = (float)((-2148.909 + 35.85*log10_e)/(-10.286 + log10_e));
  *pt = tk;
  *ptd = dewpoint;
  *prh = rh;
}
