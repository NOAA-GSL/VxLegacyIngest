#include <stdio.h>
#include <time.h>

/* file utilities/libsource.c */
/**********************************************************************/
/* f u n c t i o n   q u e r y T i m e s  */
/**********************************************************************/
/* get a range of times */
void queryTimes(time_t *timeSecs,int *ntimes)
{
  char line[80];
  char atime[10];
  int hour, julday, year;
  struct tm *tm;
  time_t makeSecs(char *atime);

  
   /* set up times */
  /* be sure environment variable TZ is null, so we're in GMT */
  /* get current year */
  time(timeSecs);
  tm = localtime(timeSecs);
  year = tm->tm_year;
  hour = tm->tm_hour;
  julday = tm->tm_yday +1;

  do {
    printf("Input starting time, or '?': ");
    gets(line);

    if(line[0] == '?')		/* loop until this fails */
      printf("Usage: hh [jjj] [yy]\n" \
	   "        where hh is the starting hour (GMT)\n" \
	   "        where jjj (optional) is the Julian day, \n" \
	   "        and yy (optional) is the year \n" \
	   "        (empty values default to current hh and jjj).\n");
  } while(line[0] == '?');

  sscanf(line, "%d %d %d", &hour, &julday, &year);

  /* get starting timeSecs (seconds since 1970 */
  sprintf(atime,"%2.2d%3.3d%2.2d00",year,julday,hour);
  printf("atime = %s\n", atime);
  *timeSecs = makeSecs(atime);

   printf("Input number of times to display: ");
  gets(line);
  sscanf(line,"%d",ntimes);
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

  tp->tm_mon = i-1;		/* months should start at zero */
  tp->tm_isdst = -1;		/* flag to calculate dst */
  tp->tm_mday = julday;		/* it is now just the left-over days */

  return mktime(tp);
}
  
/****************************************************************/
/* f u n c t i o n    g o o d o p e n  */
/****************************************************************/
/* opens a file, exits if error.  returns the file pointer */
FILE *goodopen(char *filename, char *mode)
{
  FILE *stream;
  char errline[80];		/* holds part of error message */
  printf("Opening file %s\n", filename);
  if ((stream = fopen(filename, mode)) == NULL) {
    sprintf(errline,
	    "goodopen: Cannot open file %s", filename);
    perror(errline);
    exit(1);
  }
  return stream;
}
