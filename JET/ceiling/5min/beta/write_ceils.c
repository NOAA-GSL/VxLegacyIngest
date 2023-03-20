#include <mysql.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "my_mysql_util.h"
#include "ceil_stations.h"

void write_ceils (STATION *sta[],int n_stations,
		  MYSQL *conn,
		  char *model,time_t valid_secs,
		  int fcst_len,int fcst_min,int total_min,char *data_file,int DEBUG) {

  int num_rows;
  FILE *df;
  time_t startClock;
  time_t endClock;
  float endSecs;
  long int ticks_per_sec;
  int i;
  int iceil;
  char query[500];
  STATION *sp;

  int round(float x);

  df = fopen(data_file,"w");
  if(df == NULL) {
    printf("could not open %s\n",data_file);
    exit(1);
  }
  /* loop over sites */
  for(i=0;i<n_stations;i++) {
    sp = sta[i];
    if(sp->sta_id >= 0) {
      iceil = (int)(sp->ceil +0.5);
      fprintf(df,"%d,%ld,%d,%d,%d\n",
	       sp->sta_id,
	       sp->obs_time,
	       fcst_len,
	       fcst_min,
	       iceil);
    }
  } /* end loop over stations */
  fclose(df);
  ticks_per_sec = sysconf(_SC_CLK_TCK);

  /* create temporary table to hold this data */
  snprintf(query,500,
	   "create temporary table t (\n"
	   "madis_id mediumint unsigned not null,\n"
	   "time int unsigned not null,\n"
	   "fcst_len tinyint unsigned not null,\n"
	   "fcst_min tinyint unsigned not null,\n"
	   "c smallint unsigned)");
  /* printf("%s\n",query); */
  if(mysql_query(conn,query) != 0) {
    print_error(conn,"create temporary table t failed");
    exit(1);
  }

  /* fill it up */
  startClock = times(NULL);
  snprintf(query,500,
	   "load data concurrent local infile '%s' \n"
	   "replace into table t \n"
	   "columns terminated by ',' \n"
	   "lines terminated by '\\n'\n",
	   data_file,model);
  printf("%s\n",query); 
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

  /* move data from temporary table to correct table */
  startClock = times(NULL);
  snprintf(query,500,
	   "insert into %s (madis_id,time,fcst_len,fcst_min,ceil)\n"
	   "select madis_id,time,fcst_len,fcst_min,c from t\n"
	   "on duplicate key update ceil = c\n",
	   model,fcst_len,fcst_len,fcst_min);
  printf("%s\n",query); 
  fflush(NULL);
  if(mysql_query(conn,query) != 0) {
    print_error(conn,"update table failed");
    exit(1);
  }
  endClock = times(NULL);
  endClock -= startClock;
  endSecs = ((float)endClock)/ticks_per_sec;  
  printf("%.3f sec to update table\n",endSecs);

  /* remove temporary table */
  snprintf(query,500,"drop table t");
  /* printf("%s\n",query); */
  fflush(NULL);
  if(mysql_query(conn,query) != 0) {
    print_error(conn,"drop table failed");
    exit(1);
  }
} 


 
