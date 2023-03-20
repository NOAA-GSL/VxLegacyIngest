#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <mysql.h>
#include "stations.h"

int get_stations_q(STATION *sta[], MYSQL *conn, time_t valid_secs,
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
  STATION *sptr1;
  float read_val(char *s);
  STATION *make_station();

  printf("valid_secs in get_stations is %ld\n",
	 valid_secs);

  snprintf(query,500,"select * from hr_obs_%ld\n",valid_secs);
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
	  if(0) {
	    printf("|%s| %s %s %s\n",
		   row[0],row[1],row[2],row[3]);
	  }
	  sta_id = atoi(row[0]);
	  sptr->sta_id = sta_id;
	  loc_id = atoi(row[1]);
	  sptr->loc_id = loc_id;
	  lat = atoi(row[2]);
	  sptr->lat = lat/182.;
	  lon = atoi(row[3]);
	  sptr->lon = lon/182.;
	  if(row[4] == '\0') {
	    printf("setting null elevation to zero\n");
	    elev = 0; 
	  } else {
	    elev = atoi(row[4]);
	  }
	  sptr->elev = (float)elev; /* ft */
	  obs_time = atoi(row[5]);
	  sptr->obs_time = obs_time;
	  if(strcmp(row[6],"Maritime") == 0 ||
	     strcmp(row[6],"GoMOOS") == 0) {
	    sptr->land_wat = -1;
	  } else {
	    sptr->land_wat = 1;
	  }
	  sptr->pr_ob = read_val(row[7])/10.;
	  sptr->temp_ob = read_val(row[8])/10.;
	  sptr->dew_ob = read_val(row[9])/10.;
	  sptr->windSpd_ob = read_val(row[10]);
	  sptr->windDir_ob = read_val(row[11]);
	  sptr->rh_ob = read_val(row[12])/10.;
	  sta[n_stations] = sptr;
	  if(sptr->sta_id == 582) {
            printf("%d %d %.2f %.2f %.0f %ld %.0f %.0f %.0f %.0f %.0f\n",
                   sptr->sta_id,sptr->loc_id,sptr->lat,
		   sptr->lon,sptr->elev,sptr->obs_time,sptr->land_wat,
		   sptr->pr_ob,sptr->temp_ob,sptr->dew_ob,sptr->windSpd_ob,
		   sptr->windDir_ob);
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

STATION * make_station() {
  STATION *sp;
  sp = (STATION *)malloc(sizeof(STATION));
  sp->sta_id = -1;
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
  
