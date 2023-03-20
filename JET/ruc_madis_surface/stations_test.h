#ifndef SETUP
#define SETUP
#define MAX_STATIONS 50000
#include <time.h>
#include <float.h>

typedef struct STATION {
  int sta_id;
  char name[4];
  int loc_id;
  int land_wat;			/* =1 for land, -1 for water */
  int ndiff;	/* counts neighbors with diff. land/water type than the site (0-4)*/
  float lat;
  float lon;
  float elev;
  time_t obs_time;
  int valid_time;		/* model valid time */
  float pr_ob;			/* mb*10 */
  float temp_ob;		/* farenheit*10 */
  float dew_ob;			/* farenheit*10 */
  float rh_ob;			/* in percent */
  float windSpd_ob;		/* mph */
  float windDir_ob;		/* degrees (true) */
  float pr_bilin;		/* mb, bilinear interpolation of all 4 neighbors */
  float temp_bilin;		/* farenheit, bilinear interpolation of all 4 neighbors */
  float dew_bilin;		/* farenheit, bilinear interpolation of all 4 neighbors */
  float rh_bilin;		/* percent, bilinear interpolation of all 4 neighbors */
  float windSpd_bilin;		/* mph, bilinear interpolation of all 4 neighbors */
  float windDir_bilin;		/* degrees (true), bilinear interpolation of all 4 neighbors */
  float pr_land;		/* mb, of nearest land grid pt */
  float temp_land;		/* farenheit, of nearest land grid pt */
  float dew_land;		/* farenheit, of nearest land grid pt */
  float rh_land;		/* percent, of nearest land grid pt */
  float windSpd_land;		/* mph, of nearest land grid pt */
  float windDir_land;		/* degrees (true), of nearest land grid pt */
  float r_land;		        /* distance from ob to nearest land grid pt */
  int bearing_land;	        /* bearing FROM ob to nearest land grid pt */
  float pr_water;			/* mb */
  float temp_water;		/* farenheit */
  float dew_water;			/* farenheit */
  float rh_water;			/* percent */
  float windSpd_water;		/* mph */
  float windDir_water;		/* degrees (true) */
  float r_water;		/* distance from ob to nearest water grid pt */
  int bearing_water;	/* bearing FROM ob to nearest water grid pt */
  int vgtyp;		/* VGTYP (land use category) */
} STATION;

#endif
