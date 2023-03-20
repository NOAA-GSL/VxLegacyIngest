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
#include "fv3SoundingLib.h"


int computeFV3Sounding(float *TMP, float *RH, float *U, float *V, float *Z,
                    int int_levels[], int numX, int numY, int numLevels, RAOB *raob, 
                    raob_data_struct *raob_data, float ddeg) {

    int i, j, k;

    float xcart, ycart;
    float grid_lat, grid_lon;
    float delta_east, delta_north;
    float t_kelvin,td_kelvin;
    long pr,ws,wd,t10_next,td10_next,ws_next,wd_next;
    float p, pr_next;
    float z, z_next;
    long z_interp;
    float pr_float;
    long t10,td10;
    float fact;
    int startx, starty, size;
    long index, p2index;
    float radians;
    int icount = 0;
    float tmpC;
    float pi,pi0,pi1;
    float pInterp;
    float e = 2.718281828549045;
    float cp = 1004.6855;  /* constant pressure */
    float g = 9.80665;  /* gravity */
    long hgt;

    int DEBUG = 1;

   /* pressure now in tenths of mbs */
   long mand_level[] = {10000,9250,8500,7000,6000,5000,4000,3000,2500,2000,1500,1000,700,500,300,200,100};
   int mand_levels = 17;


    long last_pressure = MISSING;
    /* compute soundings */

    /* get the appropriate i,j */
     if (DEBUG) {
     printf ("id: %d lat: %f lon: %f elev: %f \n",
      raob->raob_id,raob->lat,raob->lon, raob->elev);
     }
     get_ij(raob->lat,raob->lon,ddeg,&xcart,&ycart);
     if (DEBUG) {
        printf("xcart,ycart = %f %f\n",xcart,ycart);
     }
     /* get x,y point */
     startx = xcart+0.5;
     starty = ycart+0.5;
     if (DEBUG) {
       printf("startx: %d starty: %d\n",startx,starty); 
     }
     for (j=0; j<numLevels-1; j++) {
        pr = MISSING;
        pr_float = MISSING;
        hgt = MISSING;
        t10 = MISSING;
        td10 = MISSING;
        wd = MISSING;
        ws = MISSING;
        t_kelvin = MISSING;
        td_kelvin = MISSING;
        index = startx + (starty*numX)+ (j*numX*numY);
        if (DEBUG) {
	   printf ("level: %d P: %f %f TMP: %f RH: %f U: %f v: %f Z: %f\n",
	   j,int_levels[j],TMP[index],RH[index],U[index],V[index],Z[index]);
        }
        /*if (P[index] != MISSING && P[p2index] != MISSING) {
           p =  P[index]/10.0;
           pr_next = P[p2index]/10.0;
           pr_float = (P[index] + P[p2index]) / 2.0;
           pr = (long)(pr_float + 0.5);
           pr = pr / 10.0;
        }*/
        pr = int_levels[j]*10;  /* in tenths of mb */
        if  (TMP[index] != MISSING) {
          t_kelvin = TMP[index];
          t10 = (t_kelvin-273.15)*10 + 0.5;
        }
        hgt = (long)Z[index];
        /*if  (Z[index] != MISSING && Z[p2index] != MISSING) {
          hgt = (long)(((Z[index] + Z[p2index]) / 2.0) + 0.5);
        }*/
        if (DEBUG) {
           printf ("tmp: %f rh: %f\n",TMP[index],RH[index]); 
         }
        if  (TMP[index] != MISSING && RH[index] != MISSING && RH[index] > 1.0) {
          td_kelvin = tdBolton(TMP[index],RH[index]/100.0);
          td10 = (td_kelvin-273.15)*10 + 0.5;
        }
        if(pr < last_pressure) {
          last_pressure = pr;
          /* get wind in kts, and direction */
          if (U[index] != MISSING && V[index] != MISSING) {
            ws=(float)sqrt((double)(U[index]*U[index] + V[index]*V[index])) / 0.51479 + 0.5 ;
            radians=atan2(-U[index],-V[index]);
            wd=(long)(radians*57.2958 +  0.5);
            if(wd > 360) wd -= 360;
            if(wd < 0) wd += 360;
          }
          if(j == 0) {
            /* initial level: assume this is the surface */
            raob_data[icount].fr = 9; /*surface*/
          } else {
             raob_data[icount].fr = 5;
              for (k=0;k< mand_levels; k++) {
                 if (pr == mand_level[k]) {
                    raob_data[icount].fr = 4;
                    /* printf("EQ: pr: %d mand: %d\n",pr,mand_level[k]); */
                 }
               }
          }
          raob_data[icount].pr = pr;
          raob_data[icount].ht = hgt;
          raob_data[icount].tmp = t10;
          raob_data[icount].dp = td10;
          raob_data[icount].wd = wd;
          raob_data[icount].ws = ws;

          tmpC = t_kelvin - 273.15;
          if (DEBUG) {
	  printf(" pr: %ld ht: %ld tmp: %ld dp: %ld wd: %ld ws %ld\n",
		 raob_data[icount].pr , raob_data[icount].ht , raob_data[icount].tmp ,
		 raob_data[icount].dp , raob_data[icount].wd , raob_data[icount].ws);
          }
          icount++;

        } /* end pressure different section */
  } /* end loop over heights */
}

