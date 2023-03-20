/* wgrib2 main module:  w. ebisuzaki
 *
 * 1/2007 mods M. Schwarb: unsigned int ndata
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>
#include <ctype.h>
#include <math.h>
#include <time.h>
#include "fv3SoundingLib.h"


int main(int argc, char **argv) {
  int i,i_raob;

    float *P, *TMP, *RH, *U, *V, *Z;
    float *PW;
    float CAPE,CIn,Helic;
    float *values3d, *values2d;
    int numX = 1440;
    int numY = 721;
    int numLevels = 33;
    int numLevelsm1 = numLevels-1;
    int numRaobs;

    char month_name[4];

    char *model = argv[1];
    char *fileName = argv[2];
    char *raobFileName = argv[3];
    char *valid_time = argv[4];
    char *fcst_len = argv[5];
    raob_data_struct raob_data[numLevels];

/*    char *levels[] = {"1000 mb","975 mb","950 mb","925 mb","900 mb","875 mb","850 mb","825 mb","800 mb",
                      "775 mb","750 mb","725 mb","700 mb","675 mb","650 mb","625 mb","600 mb","575 mb",
                      "550 mb","525 mb","500 mb","475 mb","450 mb","425 mb","400 mb","375 mb","350 mb",
                      "325 mb","300 mb","275 mb","250 mb","225 mb","200 mb","175 mb","150 mb","125 mb",
                      "100 mb","70 mb","50 mb","30 mb","20 mb","10 mb","7 mb","5 mb","3 mb","2 mb","1 mb"};

    int int_levels[] = {1000,975,950,925,900,875,850,825,800,
                        775,750,725,700,675,650,625,600,575,550,525,500,475,450,425,400,
                        375,350,325,300,275,250,225,200,175,150,125,100,
                        70,50,30,20,10,7,5,3,2,1};*/

    char *levels[] = {"1000 mb","975 mb","950 mb","925 mb","900 mb","850 mb","800 mb",
                      "750 mb","700 mb","650 mb","600 mb",
                      "550 mb","500 mb","450 mb","400 mb","350 mb",
                      "300 mb","250 mb","200 mb","150 mb","100 mb",
                      "70 mb","50 mb","40 mb","30 mb","20 mb","15 mb","10 mb","7 mb","5 mb","3 mb","2 mb","1 mb"};

    int int_levels[] = {1000,975,950,925,900,850,800,
                        750,700,650,600,550,500,450,400,
                        350,300,250,200,150,100,
                        70,50,40,30,20,15,10,7,5,3,2,1};

    static char *params3d[] = {":TMP:",":RH:",":UGRD:",":VGRD:", ":HGT:"};
    static char *params2d[] = {"PWAT"};


    int num3dparams = 5;
    int num2dparams = 1;
    int startx, starty, max_id;
    long index;
    float xcart, ycart;
    float grid_lat, grid_lon;


    long num3dvalues = num3dparams * numLevels * numX * numY;
    long num2dvalues = num2dparams * numX * numY;

    float ddeg = 0.25;
    float delta_north;
    float delta_east;
    float dist;
    float dir;

    char *ptr;                    /* pointer to parts of the input filename */
    int year,month,mday,jday,hour,fcst_proj;
    time_t valid_secs;
    struct tm tm;
    struct tm *tp;

    char line[400];

    RAOB *RAOBS[MAXRAOBS];
    RAOB *rb;

    if (argc < 6) {
      printf ("fv3_soundings model gribFileName raobFileName valid_time fcst_len\n");
      exit(0);
    }

    /* get valid time from filename */
    /* e.g. "/path.../0336314000003.grib" */
    //ptr = strrchr(fileName,'/');
    //sscanf(ptr,"/%2d%3d%2d000%3d",&year,&jday,&hour,&fcst_proj);
    /* get day month and year */
    //year += 2000;
    //valid_secs = makeSecs(year,jday,hour) + 3600*fcst_proj;
    valid_secs = atoi(valid_time);
    fcst_proj = atoi(fcst_len);
   /* get tp to point to the tm structure */
    tp=&tm;
    tp = localtime(&valid_secs);
    year= tp->tm_year+1900;
    month = tp->tm_mon+1;
    mday = tp->tm_mday;
    hour = tp->tm_hour;
    (void)strftime(month_name,4,"%b",tp);

    printf("Valid Time: %s Fcst Len: %s\n",valid_time,fcst_len);
    printf("Valid Secs: %d Fcst Proj: %d\n",valid_secs,fcst_proj);
    printf("Year: %d Month: %d Day: %d Hour: %d\n",year,month,mday,hour);

    numRaobs = read_airports(RAOBS,MAXRAOBS,raobFileName,&max_id);  

     printf("Total raobs loaded = %d from file %s\n",
         numRaobs,raobFileName); 

     for (i_raob=0; i_raob<numRaobs; i_raob++) {
       rb = RAOBS[i_raob];
    }
    
    values3d = (float *)malloc(num3dvalues * sizeof(float));
    values2d = (float *)malloc(num2dvalues * sizeof(float));
    for (i=0; i< num3dvalues;i++) {
       values3d[i] = MISSING;
    }
    for (i=0; i< num2dvalues;i++) {
       values2d[i] = MISSING;
    }
    /* read grib2 2 data */
    getGrib2Data(fileName,numX,numY,numLevels,levels, params3d, params2d,
                 num3dparams,num2dparams,values3d, values2d);
     //P = &values3d[0 * numLevels * numX * numY];
     TMP = &values3d[0 * numLevels * numX * numY];
     printf("TMP: %f\n",TMP[0]);
     RH = &values3d[1 * numLevels * numX * numY];
     U = &values3d[2 * numLevels * numX * numY];
     V = &values3d[3 * numLevels * numX * numY];
     Z = &values3d[4 * numLevels * numX * numY];
     PW = &values2d[0 * numX * numY];


    /* compute sounding and print output */
    for (i_raob=1; i_raob<numRaobs; i_raob++) {

       rb = RAOBS[i_raob];
       /* get x,y point */
       get_ij(rb->lat,rb->lon,ddeg,&xcart,&ycart);
       printf("raob lat= %f raob lon= %f\n", rb->lat,rb->lon);
       startx = xcart+0.5;
       starty = ycart+0.5;
       printf("grid i= %f grid j= %f\n", startx,starty);
       index = startx + (starty*numX);

       /* get distance of FV3 sounding from site */
       get_ll(startx,starty,ddeg,&grid_lat,&grid_lon);
       printf("grid lon= %f grid lat= %f\n", grid_lon,grid_lat);
       delta_north = (grid_lat - rb->lat)*59.9; /* nautical miles */
       delta_east = (grid_lon - rb->lon)*cos(rb->lat * 0.0175)*59.9; /* nm  */
       dist = sqrt(delta_north*delta_north + delta_east*delta_east);
       dir = atan2(-delta_east, -delta_north)*57.3 + 180;
       printf("delta_east= %f delta_north= %f\n", delta_east,delta_north);

       computeFV3Sounding(TMP, RH, U, V, Z, int_levels, numX, numY, numLevels, rb,
                    &raob_data[0], ddeg);
       printf("after compute\n");
       
       CAPE = MISSING;
       CIn = MISSING;
       Helic = MISSING;
       
   /* see what it looks like */
  printf("Begin sounding data for %s:\n",rb->name);
  snprintf(line,100,"%s        % 2d     % 2d      %s    %4d",
	  model,hour,mday,month_name,year);

  printf("%s\n",line);		/* time information */
  printf("   CAPE%7.0f    CIN%7.0f  Helic%7.0f     PW%7.0f\n",
	 CAPE,CIn,Helic,PW[index]);
  
  printf("%7d%7d%7d%7.2f%7.2f%7.0f%7d\n",1,23062,rb->raob_id,
	 grid_lat,-grid_lon,rb->elev,MISSING);
  printf("%7d%7d%7d%7d%7d%7d%7d\n",
	 2,MISSING,MISSING,MISSING,numLevelsm1+4,MISSING,MISSING);
  printf("      3           %-19.19s   12     kt\n",
	 rb->name);
   for(i=0;i<numLevelsm1;i++) {
     printf("%7ld%7ld%7ld%7ld%7ld%7ld%7ld\n",
	    raob_data[i].fr,
	    raob_data[i].pr,
	    raob_data[i].ht,
	    raob_data[i].tmp,
	    raob_data[i].dp,
	    raob_data[i].wd,
	    raob_data[i].ws);
   }
   printf("End sounding data\n");
   printf("Begin hydrometeor data for %s:\n",rb->name);
   /*
   for(i=0;i<icount;i++) {
     if(
	(raob_data[i].clwmr != MISSING || raob_data[i].rwmr != MISSING ||
	   raob_data[i].snmr != MISSING || raob_data[i].icmr != MISSING ||
	   raob_data[i].grmr != MISSING)) {
	 printf("%7ld%7ld%7ld%7ld%7ld%7ld\n",
		raob_data[i].pr,
		raob_data[i].clwmr,
		raob_data[i].rwmr,
		raob_data[i].snmr,
		raob_data[i].icmr,
		raob_data[i].grmr
		);
       }
     }
   */
   printf("End hydrometeor data\n");
    }
    return 1;
}
