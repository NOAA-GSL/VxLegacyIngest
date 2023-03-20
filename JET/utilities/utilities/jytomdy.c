#include <stdio.h>
#include <stdlib.h>
#include <time.h>

/*void jytomdy (j [y])*/
void main(int argc, char *argv[])
/* returns month, day, year given julian day and [optional] year  */
/* if 1 arg, assume month and day, and current year */
{
  FILE *stream;
  struct tm tm;
  struct tm *tp;
  time_t *timeSecs;
  time_t timet;
  char line[80], atime[10];
  int month,day,year,jday;
  time_t makeSecs(char *atime);

  /* get tp to point to the tm structure */
  tp=&tm;
  timeSecs=&timet;

  /* check args */
  if(argc < 2) {
    printf("Usage: jytomdy j [y] returns date: weekday-day-month-yr\n");
    exit(1);
  }
  
  /* be sure we're in gmt */
  putenv("TZ=GMT");

  /* get current year, if we need to */
  if(argc == 2) {
    time(timeSecs);
    tp = localtime(timeSecs);
    strftime(line,80,"%y",tp);
    year=atoi(line);
  } else {
    year=atoi(argv[2]);
  }

  jday=atoi(argv[1]);

  (void) sprintf(atime,"%d%03d1200",year,jday);
  /*printf("atime = %s\n",atime);*/
  timet = makeSecs(atime);
  tp = localtime(&timet);
  /*printf("%s\n",asctime(tp));*/
  strftime(line,80,"%a-%d-%b-%y",tp);
  printf("%s\n",line);
}
  
/**********************************************************************/
/* f u n c t i o n    m a k e S e c s */
/**********************************************************************/
/* makes number of secs since 1970 from an atime.  see p 111 of
 kernighan and Richie, 2nd ed.
 */
time_t makeSecs(char *atime)
{
  struct tm tm;
  struct tm *tp;
  static int daytab[2][13] = {
    {0,31,28,31,30,31,30,31,31,30,31,30,31},
    {0,31,29,31,30,31,30,31,31,30,31,30,31}
  };
  int i,julday, leap, year;

  /* get tp to point to the tm structure */
  tp=&tm;
  
  /* decode the atime */ 
  sscanf(atime,"%2d%3d%2d%2d",
         &year,
         &julday,
         &tp->tm_hour,
         &tp->tm_min);

  tp->tm_sec=0;
  tp->tm_year = year;

  /* get month and day from julian day */
  leap = (year%4 == 0 && year%100 != 0) || year%400 == 0;
  for(i=1;julday>daytab[leap][i];i++)
    julday -= daytab[leap][i];

  tp->tm_mon = i-1;             /* months should start at zero */
  tp->tm_isdst = -1;            /* flag to calculate dst */
  tp->tm_mday = julday;         /* it is now just the left-over days */

  return mktime(tp);
}
