#include <mysql.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>
#include <math.h>
#include "my_mysql_util.h"
#include "stations.h"

void write_stations_update (STATION *sta[],int n_stations,
			 MYSQL *conn,
			 char *model,time_t valid_secs,
			 int fcst_len,int DEBUG) {

  int i;
  FILE *LOG;
  time_t startClock;
  time_t endClock;
  float endSecs;
  char valid_time_str[80];
  char job_time_str[80];
  time_t job_time;
  long int ticks_per_sec;
  int result,iprint;
  int i_coastal=0;
  char query[500];
  STATION *sp;
  int land_better;		/* shows whether variable is better for the land nearest
				* neighbor. 1-bit on if land better for press
				*           2-bin on if land better for temp
				*           4-bin on if land better for dewpt
				*           8-bit on if land better for wind */
  float best_pr,best_temp,best_dew,best_windDir,best_windSpd;

  int comp_vars(float r_land,float r_water,
		float var_ob,float var_land,float var_water, float *var_best,int debug);
  int round(float f);

  printf("model is %s\n",model);
  ticks_per_sec = sysconf(_SC_CLK_TCK);
  startClock = times(NULL);

  /* loop over sites*/
  for(i=0;i<n_stations;i++) {
    land_better=0;
    sp = sta[i];
    if(sp->sta_id >= 0) {
      /* if a 'coastal' point, find whether land or water nearest grid pt is better,
       * for each variable */
      if(sp->ndiff == 0) {
	/* all neighbors are the same; use bilin interp */
	best_pr = sp->pr_bilin;
	best_temp = sp->temp_bilin;
	best_dew = sp->dew_bilin;
	best_windSpd = sp->windSpd_bilin;
	best_windDir = sp->windDir_bilin;
	land_better = -1; /* shouldn't have to load this value into the db */
      } else {
	land_better=0;
	iprint=0;
	if(sp->sta_id == 2689) {
	  iprint=1;
	}
	/* coastal' station. compare each variable */
	land_better += 1*comp_vars(sp->r_land,sp->r_water,
				   sp->pr_ob,sp->pr_land,sp->pr_water,&best_pr,iprint);
	land_better += 2*comp_vars(sp->r_land,sp->r_water,
				   sp->temp_ob,sp->temp_land,sp->temp_water,&best_temp,iprint);
	land_better += 4*comp_vars(sp->r_land,sp->r_water,
				   sp->dew_ob,sp->dew_land,sp->dew_water,&best_dew,iprint);
	if(comp_vars(sp->r_land,sp->r_water,
		     sp->windSpd_ob,sp->windSpd_land,sp->windSpd_water,&best_windSpd,iprint) == 1) {
	  land_better += 8;
	  best_windDir = sp->windDir_land;
	} else {
	  best_windDir = sp->windDir_water;
	}
      }
      /* put the BILINEAR values into this table */
      snprintf(query,500,"insert INTO %sp "
	       "(sta_id,fcst_len,time,ndiff,press,temp,dp,wd,ws) "
	       "VALUES(%d,%d,%ld,%d,%d,%d,%d,%d,%d) "
	       "on duplicate key update "
	       "ndiff=%d,press=%d,temp=%d,dp=%d,wd=%d,ws=%d",
	       model,
	       sp->sta_id,
	       fcst_len,
	       sp->obs_time,
	       sp->ndiff,
	       round(sp->pr_bilin*10),
	       round(sp->temp_bilin*10),
	       round(sp->dew_bilin*10),
	       (int)(sp->windDir_bilin),
	       round(sp->windSpd_bilin),
	       sp->ndiff,
	       round(sp->pr_bilin*10),
	       round(sp->temp_bilin*10),
	       round(sp->dew_bilin*10),
	       (int)(sp->windDir_bilin),
	       round(sp->windSpd_bilin)
	       );
      if(i < 0) {
	printf("%s\n",query);
      }
      if(mysql_query(conn,query) != 0) {
	print_error(conn,"replace failed");
	exit(1);
      }
      /* put 1h forecasts into the long-term table */
      if(fcst_len == 1) {
      snprintf(query,500,"insert INTO %sp1f "
	       "(sta_id,time,ndiff,press,temp,dp,wd,ws) "
	       "VALUES(%d,%ld,%d,%d,%d,%d,%d,%d) "
	       "on duplicate key update "
	       "ndiff=%d,press=%d,temp=%d,dp=%d,wd=%d,ws=%d",
	       model,
	       sp->sta_id,
	       sp->obs_time,
	       sp->ndiff,
	       round(sp->pr_bilin*10),
	       round(sp->temp_bilin*10),
	       round(sp->dew_bilin*10),
	       (int)(sp->windDir_bilin),
	       round(sp->windSpd_bilin),
	       sp->ndiff,
	       round(sp->pr_bilin*10),
	       round(sp->temp_bilin*10),
	       round(sp->dew_bilin*10),
	       (int)(sp->windDir_bilin),
	       round(sp->windSpd_bilin)
	       );
	if(i < 0) {
	  printf("%s\n",query);
	}
	if(mysql_query(conn,query) != 0) {
	  print_error(conn,"replace failed");
	  exit(1);
	}
      }
      
      /* store data from 'coastal' */
      if(sp->ndiff > 0) {
	snprintf(query,500,"INSERT INTO %s_coastal5 "
		 "(sta_id,fcst_len,time,"
		 "press_land,temp_land,dp_land,wd_land,ws_land,"
                 "press_wat,temp_wat,dp_wat,wd_wat,ws_wat,"
		 "land_better) "
		 "VALUES(%d,%d,%ld,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d) "
		 "ON DUPLICATE KEY UPDATE "
		 "press_land=%d,temp_land=%d,dp_land=%d,wd_land=%d,ws_land=%d,"
                 "press_wat=%d,temp_wat=%d,dp_wat=%d,wd_wat=%d,ws_wat=%d,"
		 "land_better=%d",
		 model,
		 sp->sta_id,
		 fcst_len,
		 sp->obs_time,
		 round(sp->pr_land*10),
		 round(sp->temp_land*10),
		 round(sp->dew_land*10),
		 (int)(sp->windDir_land),
		 round(sp->windSpd_land),
		 round(sp->pr_water*10),
		 round(sp->temp_water*10),
		 round(sp->dew_water*10),
		 (int)(sp->windDir_water),
		 round(sp->windSpd_water),
		 land_better,
		 round(sp->pr_land*10),
		 round(sp->temp_land*10),
		 round(sp->dew_land*10),
		 (int)(sp->windDir_land),
		 round(sp->windSpd_land),
		 round(sp->pr_water*10),
		 round(sp->temp_water*10),
		 round(sp->dew_water*10),
		 (int)(sp->windDir_water),
		 round(sp->windSpd_water),
		 land_better
		 );
	if(mysql_query(conn,query) != 0) {
	  print_error(conn,"replace failed");
	  exit(1);
	}
	if(sp->r_land < 0) {
	  snprintf(query,500,"UPDATE %s_coastal5 "
		   "set press_land = NULL,temp_land = NULL,dp_land = NULL,"
		   "wd_land = NULL,ws_land = NULL "
		   "where sta_id = %d and fcst_len = %d and time = %ld",
		   model,
		   sp->sta_id,
		   fcst_len,
		   sp->obs_time);
	  if(mysql_query(conn,query) != 0) {
	    print_error(conn,"adding land NULLs failed");
	    exit(1);
	  }
	}   
	if(sp->r_water < 0) {
	  snprintf(query,500,"UPDATE %s_coastal5 "
		   "set press_wat = NULL,temp_wat = NULL,dp_wat = NULL,"
		   "wd_wat = NULL,ws_wat = NULL "
		   "where sta_id = %d and fcst_len = %d and time = %ld",
		   model,
		   sp->sta_id,
		   fcst_len,
		   sp->obs_time);
	  if(mysql_query(conn,query) != 0) {
	    print_error(conn,"adding water NULLs failed");
	    exit(1);
	  }
	}   
	snprintf(query,500,"INSERT INTO stations_%s_coastal5 "
		 "(sta_id,ndiff,r_land,bearing_land,r_wat,bearing_wat)"
		 "VALUES(%d,%d,%d,%d,%d,%d) "
		 "ON DUPLICATE KEY UPDATE "
		 "ndiff=%d,r_land=%d,bearing_land=%d,r_wat=%d,bearing_wat=%d",
		 model,
		 sp->sta_id,
		 sp->ndiff,
		 round(sp->r_land*13.545),
		 round(sp->bearing_land),
		 round(sp->r_water*13.545),
		 round(sp->bearing_water),
		 sp->ndiff,
		 round(sp->r_land*13.545),
		 round(sp->bearing_land),
		 round(sp->r_water*13.545),
		 round(sp->bearing_water)
		 );
	if(mysql_query(conn,query) != 0) {
	  print_error(conn,"STATION replace failed");
	  exit(1);
	}
	
      }
    }
  }  /* end loop over stations */
  endClock = times(NULL);
  endClock -= startClock;
  endSecs = ((float)endClock)/ticks_per_sec;
  strftime(valid_time_str,80,"%d-%b-%y %H Z",gmtime(&valid_secs));
  time(&job_time);
  strftime(job_time_str,80,"%d-%b-%y %H%M Z",gmtime(&job_time));
  LOG = fopen("sfc.log","a");
  fprintf(LOG,"%s %2dh forecast valid %s, run %s. Processed %d stations in %.0f secs \n",
	  model,fcst_len,valid_time_str,job_time_str,n_stations,endSecs);
  fprintf(stdout,"%s %2dh forecast valid %s, run %s. Processed %d stations in %.0f secs \n",
	  model,fcst_len,valid_time_str,job_time_str,n_stations,endSecs);
  fclose(LOG);
}

/** returns 1 if the land point matches the ob better, 0 otherwise
 */
int comp_vars(float r_land,float r_water,
	      float var_ob,float var_land,float var_water, float *var_best,int debug) {
  int result = 0;		/* = 1 if land value matches ob better */
  if(r_land < 0) {
    /* no land points surround this ob. So the water nn must be better */
    result = 0;
    *var_best = var_water;
  } else if(r_water < 0) {
    /* no water points surround this ob, so land nn must be better */
    result = 1;
    *var_best = var_land;
  } else {
    /* both land and water points surround this. Find the better match */
    if(fabs(var_ob - var_land) < fabs(var_ob - var_water)) {
      /* land point matches better */
      result = 1;
      *var_best = var_land;
    } else {
      result=0;
      *var_best = var_water;
    }
    if(debug == 1) {
      printf("ob,land,water,result: %f %f %f %d\n",
	     var_ob,var_land,var_water,result);
    }
  }
  return(result);
}

int round(float f) {
  return (int)(f + (f >= 0 ? 0.5 : -0.5));
}
  
 
