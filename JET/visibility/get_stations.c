#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <mysql.h>
#include "ceil_stations.h"

int get_stations(STATION *sta[], MYSQL *conn, time_t valid_secs,
		 int DEBUG) {
  MYSQL_RES *res_set;
  MYSQL_ROW row;
  int n_stations = 0;
  char query[500];
  char table_name[100];
  int print_this;
  int sta_id,loc_id,lat,lon,elev;
  time_t obs_time;
  STATION *sptr;

  printf("valid_secs in get_stations is %ld\n",
	 valid_secs);

  snprintf(query,500,
	   "select obs.madis_id,time,lat,lon\n"
	   "from obs,metars where\n"
	   "obs.madis_id = metars.madis_id\n"
	   "and obs.time >= %ld - 1800\n"
	   "and obs.time < %ld + 1800",
	   valid_secs,valid_secs);
  if(DEBUG != 0) {
    printf("query 1: \n%s\n;\n\n",query);
  }
  if(mysql_query(conn,query) != 0) {
    print_error(conn,"query 1 failed");
    exit(1);
  } else {
      res_set = mysql_use_result(conn);
      if(res_set == NULL) {
	print_error(conn, "store_result failed");
      } else {
	while((row = mysql_fetch_row(res_set)) != NULL) {
	  sptr = (STATION *)malloc(sizeof(STATION));
	  if(sptr == NULL) {
	    printf("no more memory for station %d\n",n_stations);
	    exit(1);
	  }
	  if(0) {
	    printf("|%s| %s %s %s\n",
		   row[0],row[1],row[2],row[3]);
	  }
	  sta_id = atoi(row[0]);
	  sptr->sta_id = sta_id;
	  obs_time = atoi(row[1]);
	  sptr->obs_time = obs_time;
	  lat = atoi(row[2]);
	  sptr->lat = lat/100.;
	  lon = atoi(row[3]);
	  sptr->lon = lon/100.;
	  sta[n_stations] = sptr;
          if(DEBUG != 0 && n_stations < 10) {
            printf("%d %f %f %ld\n",
                   sptr->sta_id,sptr->lat,
		   sptr->lon,sptr->obs_time);
          }
	    
  	  n_stations++;
	  if(n_stations > MAX_STATIONS) {
	    printf("too many stations!  Change MAX_STATIONS in stations.h\n");
	    exit(1);
	  }
	}
	mysql_free_result(res_set);
      }
    }
  return(n_stations); 
}
