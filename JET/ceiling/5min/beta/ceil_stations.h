#ifndef SETUP
#define SETUP
#define MAX_STATIONS 50000
#include <time.h>
#include <float.h>

typedef struct STATION {
  int sta_id;
  float lat;
  float lon;
  time_t obs_time;
  float ceil;		/* ceiling, ft, AGL */
} STATION;
 
#endif
