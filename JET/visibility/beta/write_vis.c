#include <mysql.h>
#include <stdio.h>
#include <stdlib.h>
#include "my_mysql_util.h"
#include "vis_stations.h"

void write_vis (STATION *sta[],int n_stations,
		     MYSQL *conn,
		     char *model,time_t valid_secs,
		     int fcst_len,int DEBUG) {

  int i;
  int ivis;
  int n_stations_written=0;
  char query[500];
  char tmp_file_name[100];
  FILE *fp;
  int pid;
  STATION *sp;

  int round(float x);

  /* open temporary file */
  pid = getpid();
  sprintf(tmp_file_name,"tmp/%d_vis_data.tmp",pid);
  fp = fopen(tmp_file_name,"w+");
  if(fp == NULL) {
    printf("could not open %s\n",tmp_file_name);
    exit(1);
  }
  printf("tmp file name: |%s|\n",tmp_file_name);

  printf("model is %s\n",model);
  /* loop over sites */
  for(i=0;i<n_stations;i++) {
    sp = sta[i];
    if(sp->sta_id >= 0) {
      ivis = (int)(sp->vis100 +0.5);
      fprintf(fp,"%d,%ld,%d,%d\n",
	       sp->sta_id,
	       sp->obs_time,
	       fcst_len,
	      ivis);
      n_stations_written++;
    }
  }
  close(fp);
  printf("%d stations written to %s\n",n_stations_written,tmp_file_name);
  sprintf(query,
	  "load data concurrent local infile '%s'\n"
	  "replace into table %s columns terminated by ','\n"
	  "(madis_id,time,fcst_len,vis100)",tmp_file_name,model);
  printf("%s\n",query);  
  if(mysql_query(conn,query) != 0) {
    print_error(conn,"replace failed");
    exit(1);
  }
  if(unlink(tmp_file_name) < 0) {
    printf("could not unlink %s\n",tmp_file_name);
    exit(1);
  }
}

 
