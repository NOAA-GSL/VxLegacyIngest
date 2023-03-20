#include <stdio.h>
#include <stdlib.h>
#include <time.h>

/*void mdytoj (m d [y])*/
void main(int argc, char *argv[])
/* returns julian day.  */
/* if 2 args, assume month and day, and current year */
{
  FILE *stream;
  struct tm tm;
  struct tm *tp;
  time_t *timeSecs;
  time_t timet;
  char line[80];
  int month,day,year;

  /* get tp to point to the tm structure */
  tp=&tm;
  timeSecs=&timet;

  /* check args */
  if(argc < 3) {
    printf("Usage: mdytoj month day [year] returns julian day.\n");
    exit(1);
  }
  
  /* be sure we're in gmt */
  putenv("TZ=GMT");

  /* get current year, if we need to */
  if(argc == 3) {
    time(timeSecs);
    tp = localtime(timeSecs);
    strftime(line,80,"%y",tp);
    year=atoi(line);
  } else {
    year=atoi(argv[3]);
  }

  month=atoi(argv[1]);
  day=atoi(argv[2]);
  
  tp->tm_year=year;
  tp->tm_mon=month-1;
  tp->tm_mday=day;
  tp->tm_hour=0;
  tp->tm_min=0;
  tp->tm_sec=0;
  tp->tm_isdst=0;               /* no daylight savings time */
  *timeSecs=mktime(tp);
  strftime(line,10,"%j",gmtime(timeSecs));

  printf("Julian day for (mdy): %d %d %d is %s\n",month,day,year,line);
}
  
