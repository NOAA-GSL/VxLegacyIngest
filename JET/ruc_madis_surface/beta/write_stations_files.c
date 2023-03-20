#include <mysql.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <math.h>
#include "my_mysql_util.h"
#include "stations.h"

void write_stations_files (STATION *sta[],int n_stations,
			 MYSQL *conn,
			 char *model,time_t valid_secs,
			 int fcst_len,char *data_file,char *data_1f_file,
			 char *coastal_file, char *coastal_station_file,
			 int DEBUG) {

  int num_rows;
  FILE *df;
  FILE *df1;
  FILE *cf;
  FILE *csf;
  time_t startClock;
  time_t endClock;
  float endSecs;
  long int ticks_per_sec;
  int i;
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
  void print_land_wat(FILE *fp,float r,float pr,float temp,
		      float dew,float windDir,float windSpd);

  printf("model is %s\n",model);
  
  df = fopen(data_file,"w");
  if(df == NULL) {
    printf("could not open %s\n",data_file);
    exit(1);
  }
  df1 = fopen(data_1f_file,"w");
  if(df1 == NULL) {
    printf("could not open %s\n",data_1f_file);
    exit(1);
  }
  cf = fopen(coastal_file,"w");
  if(cf == NULL) {
    printf("could not open %s\n",coastal_file);
    exit(1);
  }
  csf = fopen(coastal_station_file,"w");
  if(csf == NULL) {
    printf("could not open %s\n",coastal_station_file);
    exit(1);
  }
  /* loop over sites */
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
	if(sp->sta_id == 2689) {
	  printf("Station 2689: dew: ob,land,wat, best,result: %f %f %f %f %d\n",
		 sp->dew_ob,sp->dew_land,sp->dew_water,best_dew,land_better);
	}
	if(comp_vars(sp->r_land,sp->r_water,
		     sp->windSpd_ob,sp->windSpd_land,sp->windSpd_water,&best_windSpd,iprint) == 1) {
	  land_better += 8;
	  best_windDir = sp->windDir_land;
	} else {
	  best_windDir = sp->windDir_water;
	}
      }
      /* put the BILINEAR values into this table */
      fprintf(df,"%d,%d,%ld,%d,%d,%d,%d,%d,%d\n",
	       sp->sta_id,
	       fcst_len,
	       sp->obs_time,
	       sp->ndiff,
	       round(sp->pr_bilin*10),
	       round(sp->temp_bilin*10),
	       round(sp->dew_bilin*10),
	       (int)(sp->windDir_bilin),
	       round(sp->windSpd_bilin)
	       );
      /* put 1h forecasts into the long-term table */
      if(fcst_len == 1) {
	fprintf(df1,"%d,%d,%ld,%d,%d,%d,%d,%d\n",
		 sp->sta_id,
		 sp->obs_time,
		 sp->ndiff,
		 round(sp->pr_bilin*10),
		 round(sp->temp_bilin*10),
		 round(sp->dew_bilin*10),
		 (int)(sp->windDir_bilin),
		 round(sp->windSpd_bilin)
		 );
      }
      /* store data from 'coastal' */
      if(sp->ndiff > 0) {
	fprintf(cf,"%d,%d,%ld,",
		sp->sta_id,
		fcst_len,
		sp->obs_time);
	print_land_wat(cf,sp->r_land,sp->pr_land,sp->temp_land,sp->dew_land,
		       sp->windDir_land,sp->windSpd_land);
	print_land_wat(cf,sp->r_water,sp->pr_water,sp->temp_water,sp->dew_water,
		       sp->windDir_water,sp->windSpd_water);
	fprintf(cf,"%d\n",land_better);

	/* update coastal stations */
	fprintf(csf,"%d,%d,%d,%d,%d,%d\n",
		 sp->sta_id,
		 sp->ndiff,
		 round(sp->r_land*13.545),
		 round(sp->bearing_land),
		 round(sp->r_water*13.545),
		 round(sp->bearing_water)
		 );
      }	/* end coastal secion  */
    } /* end check on sta_id > 0 */
  }/* end of loop over stations */
  fclose(df);
  ticks_per_sec = sysconf(_SC_CLK_TCK);
  startClock = times(NULL);
  snprintf(query,500,
	   "load data concurrent local infile '%s' \n"
	   "replace into table %sp \n"
	   "columns terminated by ',' \n"
	   "lines terminated by '\\n'\n",
	   data_file,model);
  printf("%s",query);
  fflush(NULL);
  if(mysql_query(conn,query) != 0) {
    print_error(conn,"LOAD_DATA failed");
    exit(1);
  }
  num_rows = mysql_affected_rows(conn);
  printf("%d rows affected\n",num_rows); 
  endClock = times(NULL);
  endClock -= startClock;
  endSecs = ((float)endClock)/ticks_per_sec;  
  printf("%.3f sec to load data file into mysql\n",endSecs);

  fclose(df1);
  if(fcst_len == 1) {
    ticks_per_sec = sysconf(_SC_CLK_TCK);
    startClock = times(NULL);
    snprintf(query,500,
	     "load data concurrent local infile '%s' \n"
	     "replace into table %sp1f \n"
	     "columns terminated by ',' \n"
	     "lines terminated by '\\n'\n",
	     data_1f_file,model);
    printf("%s",query);
    fflush(NULL);
    if(mysql_query(conn,query) != 0) {
      print_error(conn,"LOAD_DATA failed");
      exit(1);
    }
    num_rows = mysql_affected_rows(conn);
    printf("%d rows affected\n",num_rows);
    endClock = times(NULL);
    endClock -= startClock;
    endSecs = ((float)endClock)/ticks_per_sec;  
    printf("%.3f sec to load 1h fcst file into mysql\n",endSecs);
  }
  
  fclose(cf);
  ticks_per_sec = sysconf(_SC_CLK_TCK);
  startClock = times(NULL);
  snprintf(query,500,
	   "load data concurrent local infile '%s' \n"
	   "replace into table %s_coastal5 \n"
	   "columns terminated by ',' \n"
	   "lines terminated by '\\n'\n",
	   coastal_file,model);
  printf("%s",query);
  fflush(NULL);
  if(mysql_query(conn,query) != 0) {
    print_error(conn,"LOAD coastal data failed");
    exit(1);
  }
  num_rows = mysql_affected_rows(conn);
  printf("%d rows affected\n",num_rows); 
  endClock = times(NULL);
  endClock -= startClock;
  endSecs = ((float)endClock)/ticks_per_sec;  
  printf("%.3f sec to load coastal file into mysql\n",endSecs);
  
  fclose(csf);
  ticks_per_sec = sysconf(_SC_CLK_TCK);
  startClock = times(NULL);
  snprintf(query,500,
	   "load data concurrent local infile '%s' \n"
	   "replace into table stations_%s_coastal5 \n"
	   "columns terminated by ',' \n"
	   "lines terminated by '\\n'\n",
	   coastal_station_file,model);
  printf("%s",query);
  fflush(NULL);
  if(mysql_query(conn,query) != 0) {
    print_error(conn,"LOAD coastal stations failed");
    exit(1);
  }
  num_rows = mysql_affected_rows(conn);
  printf("%d rows affected\n",num_rows); 
  endClock = times(NULL);
  endClock -= startClock;
  endSecs = ((float)endClock)/ticks_per_sec;  
  printf("%.3f sec to load coastal stations  into mysql\n",endSecs);
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
  
void print_land_wat(FILE *fp,float r,float pr,float temp,
		    float dew,float windDir,float windSpd) {
  if(r < 0) {
    /* output nulls */
    fprintf(fp,"\\N,\\N,\\N,\\N,\\N,");
  } else {
    fprintf(fp,"%d,%d,%d,%d,%d,",
	    round(pr*10),
	    round(temp*10),
	    round(dew*10),
	    (int)(windDir),
	    round(windSpd));
  }
  return;
}
 
