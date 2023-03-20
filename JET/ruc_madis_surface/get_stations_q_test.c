#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <mysql.h>
#include "stations_test.h"

int get_stations_q(STATION *sta[], MYSQL *conn, time_t valid_secs,
		   char *nets,int DEBUG) {
  MYSQL_RES *res_set,*station_set,*location_set;
  MYSQL_ROW row,srow,lrow;
  int n_stations = 0;
  char query[500];
  char table_name[100];
  int print_this;
  int sta_id,loc_id,lat,lon,elev,i;
  time_t obs_time;
  STATION *sptr;
  STATION *sptr1;
  float read_val(char *s);
  STATION *make_station();

  printf("valid_secs in get_stations is %ld\n",
	 valid_secs);

  snprintf(query,500,"select name, id from stations where net = 'METAR' and last >= 1638316800 order by id\n");
  if(DEBUG != 0) {
    printf("query 3: \n%s\n;\n\n",query);
  }
  if(mysql_query(conn,query) != 0) {
    print_error(conn,"query 3 failed");
    exit(1);
  } else {
      res_set = mysql_use_result(conn);
      if(res_set == NULL) {
	print_error(conn, "store_result failed");
      } else {
	while((row = mysql_fetch_row(res_set)) != NULL) {
	  sptr = make_station();
	  if(sptr == NULL) {
	    printf("no more memory for station %d\n",n_stations);
	    exit(1);
	  }
          strcpy(sptr->name,row[0]);
	  sta_id = atoi(row[1]);
	  sptr->sta_id = sta_id;
	  sta[n_stations] = sptr;
  	  n_stations++;
	  if(n_stations > MAX_STATIONS) {
	    printf("too many stations!  Change MAX_STATIONS in stations.h\n");
	    exit(1);
	  }
	}
	mysql_free_result(res_set);

	printf("stations pulled!\n");

        for(i=0;i<n_stations;i++) {
           sptr = sta[i];
           sta_id = sptr->sta_id;
           snprintf(query,500,"select max(loc_id) from obs where sta_id = %ld and time >= 1638316800\n",sta_id);
           if(mysql_query(conn,query) != 0) {
                print_error(conn,"station name query failed");
                exit(1);
           } else {
                station_set = mysql_use_result(conn);
                if(station_set == NULL) {
                        print_error(conn, "finding location id failed failed");
                        continue;
                } else {
                        srow = mysql_fetch_row(station_set);
                        /*sptr->name = srow[0];*/
			loc_id = atoi(srow[0]);
                }       
                mysql_free_result(station_set);
           } 
           snprintf(query,500,"select lat, lon from locations where id = %ld\n",loc_id);
           if(mysql_query(conn,query) != 0) {
                print_error(conn,"station name query failed");
                exit(1);
           } else {
                location_set = mysql_use_result(conn);
                if(location_set == NULL) {
                        print_error(conn, "finding location id failed failed");
                        continue;
                } else {
                        lrow = mysql_fetch_row(location_set);
                        lat = atoi(lrow[0]);
          		sptr->lat = lat/182.;
          		lon = atoi(lrow[1]);
          		sptr->lon = lon/182.;
                }       
                mysql_free_result(location_set);
           }     
           sta[i] = sptr;
          if(sptr->sta_id == 146606) {
               printf("%s %d %d %.4f %.4f\n",
                   sptr->name,sptr->sta_id,sptr->loc_id,sptr->lat,
                   sptr->lon);
          }
        }

	printf("station names stored!\n");
      }
    }
  return(n_stations); 
}

STATION * make_station() {
  STATION *sp;
  sp = (STATION *)malloc(sizeof(STATION));
  sp->sta_id = -1;
  /*sp->name = "";*/
  strcpy(sp->name,"    ");
  sp->loc_id = -1;
  sp->land_wat = 0;		
  sp->ndiff = -1;
  sp->lat = -1;
  sp->lon = -1;
  sp->elev = -1;
  sp->obs_time = -1;
  sp->valid_time = -1;	
  sp->pr_ob = -1;		
  sp->temp_ob = -1;	
  sp->dew_ob = -1;		
  sp->rh_ob = -1;	
  sp->windSpd_ob = -1;	
  sp->windDir_ob = -1;	
  sp->pr_bilin = -1;	
  sp->temp_bilin = -999;	
  sp->dew_bilin = -999;	
  sp->rh_bilin = -999;	
  sp->windSpd_bilin = -999;	
  sp->windDir_bilin = -999;	
  sp->pr_land = -999;	
  sp->temp_land = -999;	
  sp->dew_land = -999;	
  sp->rh_land = -999;	
  sp->windSpd_land = -999;	
  sp->windDir_land = -999;	
  sp->r_land = -999;		
  sp->bearing_land = -999;	
  sp->pr_water = -999;	
  sp->temp_water = -999;	
  sp->dew_water = -999;	
  sp->rh_water = -999;	
  sp->windSpd_water = -999;	
  sp->windDir_water = -999;	
  sp->r_water = -999;	
  sp->bearing_water = -999;
  return(sp);
}


void printstation(STATION *s) {
  printf("%6d %5.2f %7.2f %4.0f %ld %d ndiff: %d bilin temp, ws: %.2f %.0f",
	 s->sta_id,s->lat,s->lon,s->elev,s->obs_time,
	 s->land_wat,s->ndiff,
	 s->temp_bilin,s->windSpd_bilin);

  if(s->ndiff >= 0) {
    printf(" (r,temp land: %.2f %.0f water: %.2f %.0f)\n",
	 s->r_land,s->temp_land,
	 s->r_water,s->temp_water);
  } else {
    printf("\n");
  }
}

float read_val(char *s) {
  float result = -99999;
  if(s != '\0') {			/* null value in the db */
    result = atof(s);
  }
  return result;
}
  
