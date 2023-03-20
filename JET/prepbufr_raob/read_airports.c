#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <sys/types.h>
#include "gen_soundings.h"

/**********************************************************************/
/* function read_airports */
/**********************************************************************/
/* reads list of airports*/
int read_airports(AIRPORT *p[],int max, char *filename,
		  int* max_id)
{
  FILE *stream;			/* stream to read tn's from */
  static size_t airport_len = sizeof(AIRPORT);  
  int i,count;
  char line[100];
  int id,id_last;
  int wmo_id;
  char name[5];
  int items_read;
  float lat,lon,elev;
  int known_airports=0;
  int current_max_id=0;
  char fmt[100];
  size_t trimwhitespace(char *out, size_t len, const char *str);
  id_last=-1;
  stream = fopen(filename, "r");
  if(stream == NULL) {
    fprintf(stderr,"read_airports: Can't open file %s\n",filename);
    exit(1);
  }
  p[0] = (AIRPORT *) malloc(airport_len);
  p[0]->id=0;
  strcpy(p[0]->name,"    ");
  p[0]->lat = BADOBSFLAG;
  p[0]->lon = BADOBSFLAG;
  p[0]->elev = BADOBSFLAG;
  strcpy(p[0]->line,"    0      \n");
  snprintf(fmt,100,"%%d %%%ds %%d %%f %%f %%f",AIRPORT_ID_LEN-1);
  for(i=1;i<max;) {
    if(fgets(line,100,stream) == NULL) {
      break;			/* EOF */
    } else if(line[0]==';') {	/* a comment */
      ;
    } else {
      /* find a place for this airport */
      p[i]=(AIRPORT *) malloc(airport_len);
      items_read = sscanf(line,fmt,&id,name,&wmo_id,&lat,&lon,&elev);
      /*printf("%d |%s|\n",wmo_id,name);*/
      if(items_read >= 2) {
	if(id > current_max_id) {
	  current_max_id = id;
	}
	p[i]->id = id;
	/*snprintf(p[i]->name,6,"%-5.5s",name);*/
	trimwhitespace(p[i]->name,6,name);
	strcpy(p[i]->line,line);
	if(items_read >= 5) {
	  p[i]->wmo_id = wmo_id;
	  p[i]->lat = lat;
	  p[i]->lon = lon;
	  p[i]->elev = elev; /* m -> m, for this application */
	  known_airports++;
	} else {
	  p[i]->wmo_id = 0;
	  p[i]->lat = BADOBSFLAG;
	  p[i]->lon = BADOBSFLAG;
	  p[i]->elev = BADOBSFLAG;
	}
	/* printf("%d |%s|\n",p[i]->wmo_id ,p[i]->name);*/
	i++;
      } else {
	/* if items_read < 2, it means we read a blank line */
	break;
      }
    }
  }
  *max_id = current_max_id;
  
  printf("%d known airports loaded\n",known_airports);
  
  count=i;
  
  return count;
}
/*
// Stores the trimmed input string into the given output buffer, which must be
// large enough to store the result.  If it is too small, the output is
// truncated.
*/
size_t trimwhitespace(char *out, size_t len, const char *str)
{
  if(len == 0)
    return 0;

  const char *end;
  size_t out_size;

  /* Trim leading space*/
  while(isspace((unsigned char)*str)) str++;

  if(*str == 0)  /* All spaces? */
  {
    *out = 0;
    return 1;
  }

  /* Trim trailing space */
  end = str + strlen(str) - 1;
  while(end > str && isspace((unsigned char)*end)) end--;
  end++;

  /* Set output size to minimum of trimmed string length and buffer size minus 1 */
  out_size = (end - str) < len-1 ? (end - str) : len-1;

  /* Copy trimmed string and add null terminator */
  memcpy(out, str, out_size);
  out[out_size] = 0;

  return out_size;
}