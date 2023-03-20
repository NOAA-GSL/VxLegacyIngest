#include <mysql.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <math.h>
#include "my_mysql_util.h"
#include "stations.h"

void write_stations5q (STATION *sta[],int n_stations,
		      MYSQL *conn,
		      char *model,time_t valid_secs,
		      int fcst_len,
		      char *data_file,char *data_1f_file,
		      char *coastal_file,char *coastal_station_file,
		      int DEBUG) {

  int num_rows;
  FILE *df;
  FILE *df1;
  FILE *cf;
  FILE *csf;
  MYSQL_RES *res_set;
  MYSQL_ROW row;
  time_t startClock;
  time_t endClock;
  float endSecs;
  long int ticks_per_sec;
  int i;
  int result,iprint;
  int i_coastal=0;
  char query[500];
  char field_list[100];
  char field_list1[100];
  char result_str[20];
  STATION *sp;
  int land_better;		/* shows whether variable is better for the land nearest
				* neighbor. 1-bit on if land better for press
				*           2-bin on if land better for temp
				*           4-bin on if land better for dewpt
				*           8-bit on if land better for wind */
  float best_pr,best_temp,best_dew,best_rh,best_windDir,best_windSpd;
  int has_vgtyp = 0;		/* =1 if the 'vgtyp' column is in the table */

  int comp_vars(float r_land,float r_water,
		float var_ob,float var_land,float var_water, float *var_best,int debug);
  int round(float f);
  void print_land_wat(FILE *fp,float r,float pr,float temp,
		      char *dew,float windDir,float windSpd);
  void code_nulls(float arg,char *result_str);
  void show_warnings(MYSQL *conn);

  printf("model is %s\n",model);
  /* find whether model tables have 'new' variables */
  /* assume that if the <model>qp table has it, the <model>qp1f tabls also has it. */
  snprintf(query,500,"describe %sqp",model);
  if(mysql_query(conn,query) != 0) {
    print_error(conn,"query 3 failed");
    exit(1);
  } else {
      res_set = mysql_use_result(conn);
      if(res_set == NULL) {
	print_error(conn, "store_result failed");
      } else {
	while((row = mysql_fetch_row(res_set)) != NULL) {
	  if(0) {
	    printf("|%s| %s %s %s\n",
		   row[0],row[1],row[2],row[3]);
	  }
	  if(strcmp(row[0],"vgtyp") == 0) {
	    has_vgtyp = 1;
	    break;
	  }
	}
      }
  }
  mysql_free_result(res_set);
  
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
    if(sp->pr_bilin >= 0 &&
       /* if no pressure, assume the station wasn't processed; GLMP has missing data */
       sp->sta_id >= 0) {
      if(sp->sta_id == 1365) {
	printf("\nid: %d, time: %d, lat %.2f, lon %.2f, pr %.2f, temp %.2f\n",
	       sp->sta_id,sp->obs_time,sp->lat,sp->lon,sp->pr_bilin,sp->temp_bilin);
      }
      /* if a 'coastal' point, find whether land or water nearest grid pt is better,
       * for each variable */
      if(sp->ndiff == 0) {
	/* all neighbors are the same; use bilin interp */
	best_pr = sp->pr_bilin;
	best_temp = sp->temp_bilin;
	best_dew = sp->dew_bilin;
	best_rh = sp->rh_bilin;
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
      /* put the BILINEAR values into this table (except vgtyp is nearest neighbor) */
      code_nulls(sp->dew_bilin*10,result_str);
      fprintf(df,"%d,%d,%ld,%d,%d,%d,%s,%d,%d,%d",
	      sp->sta_id,
	      fcst_len,
	      sp->obs_time,
	      sp->ndiff,
	      round(sp->pr_bilin*10),
	      round(sp->temp_bilin*10),
	      result_str,
	      (int)(sp->windDir_bilin),
	      round(sp->windSpd_bilin),
	      round(sp->rh_bilin*10)
	      );
      if(has_vgtyp) {
	fprintf(df,",%d\n",sp->vgtyp);
      } else {
	fprintf(df,"\n");
      }
     
      /* put 1h forecasts into the long-term table */
      if(fcst_len == 1) {
	code_nulls(sp->dew_bilin*10,result_str);
	fprintf(df1,"%d,%ld,%d,%d,%d,%s,%d,%d,%d",
		sp->sta_id,
		sp->obs_time,
		sp->ndiff,
		round(sp->pr_bilin*10),
		round(sp->temp_bilin*10),
		result_str,
		(int)(sp->windDir_bilin),
		round(sp->windSpd_bilin),
		round(sp->rh_bilin*10)
		);
	if(has_vgtyp) {
	  fprintf(df1,",%d\n",sp->vgtyp);
	} else {
	  fprintf(df1,"\n");
	}
      }
     
      /* store data from 'coastal' */
      if(sp->ndiff > 0) {
	fprintf(cf,"%d,%d,%ld,",
		sp->sta_id,
		fcst_len,
		sp->obs_time);
	code_nulls(sp->dew_land,result_str);
	print_land_wat(cf,sp->r_land,sp->pr_land,sp->temp_land,result_str,
		       sp->windDir_land,sp->windSpd_land);
	code_nulls(sp->dew_water,result_str);
	print_land_wat(cf,sp->r_water,sp->pr_water,sp->temp_water,result_str,
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
      }	/* end coastal section */
    } /* end check on sta_id > 0 */
  } /* end of loop over stations */

  fclose(df);
  ticks_per_sec = sysconf(_SC_CLK_TCK);
  startClock = times(NULL);
  snprintf(field_list,100,"sta_id,fcst_len,time,ndiff,press,temp,dp,wd,ws,rh");
  snprintf(field_list1,100,"sta_id,time,ndiff,press,temp,dp,wd,ws,rh");
  if(has_vgtyp) {
    strcat(field_list,",vgtyp");
    strcat(field_list1,",vgtyp");
  }
  snprintf(query,500,
	   "load data concurrent local infile '%s' \n"
	   "replace into table %sqp  \n"
	   "columns terminated by ',' \n"
	   "lines terminated by '\\n' (%s)\n",
	   data_file,model,field_list);
  printf("%s",query);
  fflush(NULL);
  if(mysql_query(conn,query) != 0) {
    print_error(conn,"LOAD_DATA failed");
    exit(1);
  }
  num_rows = mysql_affected_rows(conn);
  printf("%d rows affected\n",num_rows);
  show_warnings(conn);
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
	     "replace into table %sqp1f \n"
	     "columns terminated by ',' \n"
	     "lines terminated by '\\n'  (%s)\n",
	     data_1f_file,model,field_list1);
    printf("%s",query);
    fflush(NULL);
    if(mysql_query(conn,query) != 0) {
      print_error(conn,"LOAD_DATA failed");
      exit(1);
    }
    num_rows = mysql_affected_rows(conn);
    printf("%d rows affected\n",num_rows);
    show_warnings(conn);
    endClock = times(NULL);
    endClock -= startClock;
    endSecs = ((float)endClock)/ticks_per_sec;  
    printf("%.3f sec to load 1h fcst file into mysql\n",endSecs);
  }
  fclose(cf);
  fclose(csf);
 
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
		    char *dew,float windDir,float windSpd) {
  if(r < 0) {
    /* output nulls */
    fprintf(fp,"\\N,\\N,\\N,\\N,\\N,");
  } else {
    fprintf(fp,"%d,%d,%s,%d,%d,",
	    round(pr*10),
	    round(temp*10),
	    dew,
	    (int)(windDir),
	    round(windSpd));
  }
  return;
}

void code_nulls(float arg, char *result_str) {
  int len = 20;
  if(isnan(arg)) {
    snprintf(result_str,len,"\\N");
  } else {
    snprintf(result_str,len,"%.0f",arg);
  }
}

void show_warnings(MYSQL *conn) {
  char query[500];
  MYSQL_RES *res_set;
  MYSQL_ROW row;
  snprintf(query,500,"show warnings");
  if(mysql_query(conn,query) != 0) {
    print_error(conn,"could not show warnings!\n");
    exit(1);
  } else {
    res_set = mysql_use_result(conn);
    if(res_set == NULL) {
      print_error(conn, "show warnings failed");
    } else {
      while((row = mysql_fetch_row(res_set)) != NULL) {
	printf("%s %s %s\n",row[0],row[1],row[2]);
      }
    }
  }
  mysql_free_result(res_set);
}
 
