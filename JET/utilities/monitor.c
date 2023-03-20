/* file utilities/monitor.c */
/* monitors receipt of various files */

#include <stdio.h>
#include <time.h>

main ()
{
  char atime[10];
  char file[50], line[80];
  int i,j;
  FILE *stream;
  void latestMapstime(char *atime); /* function template */

  /* get latest mapstime */
  latestMapstime(atime);

  /* look for qcobs file */
  sprintf(file,"qcobData/%spireps.bin",atime);
  if ((stream = fopen(file, "r")) == NULL) {
    /* file not found! */
    printf("%s is missing!\n",file);
    exit(1);
  }
  exit(0);
}

/**********************************************************************/
/* f u n c t i o n    l a t e s t M a p s t i m e */
/* gets latest 3-hour atime */

void latestMapstime(char *atime)
{
  struct tm *tm;
  time_t timeSecs;		/* seconds since 1970 */

  /* get current time */
  time(&timeSecs);

  /* get latest 3-hour block minus two maps times*/
  timeSecs = (timeSecs/10800) * 10800 - 21600;

  /* fill the tm structure */
  tm = gmtime(&timeSecs);
  strftime(atime,10,"%y%j%H%M",tm);
  return;
}

    
 
