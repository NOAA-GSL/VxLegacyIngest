#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>


void w3fb08(float alat,float alon,float alat1,float alon1,float alatin,float dx,float *pxi, float *pxj)
{

  double rerth, pi, radpd, degpr, clain, dellon, djeo;

/* C$$$   SUBPROGRAM  DOCUMENTATION  BLOCK
 C
 C SUBPROGRAM:  W3FB08        LAT/LON TO MERC (I,J) FOR GRIB
 C   PRGMMR: STACKPOLE        ORG: NMC42       DATE:88-04-05
 C
 C ABSTRACT: CONVERTS A LOCATION ON EARTH GIVEN IN
 C   THE COORDINATE SYSTEM OF LATITUDE/LONGITUDE TO AN (I,J)
 C   COORDINATE SYSTEM OVERLAID ON A MERCATOR MAP PROJECTION
 C   W3FB08 IS THE REVERSE OF W3FB09
 C   USES GRIB SPECIFICATION OF THE LOCATION OF THE GRID
 C
 C PROGRAM HISTORY LOG:
 C   88-03-01  ORIGINAL AUTHOR:  STACKPOLE, W/NMC42
 C   90-04-12  R.E.JONES   CONVERT TO CRAY CFT77 FORTRAN
 C
 C USAGE:  CALL W3FB08 (ALAT,ALON,ALAT1,ALON1,ALATIN,DX,XI,XJ)
 C   INPUT ARGUMENT LIST:
 C     ALAT     - LATITUDE IN DEGREES (NEGATIVE IN SOUTHERN HEMIS)
 C     ALON     - EAST LONGITUDE IN DEGREES, REAL*4
 C     ALAT1    - LATITUDE  OF LOWER LEFT CORNER OF GRID (POINT (1,1))
 C     ALON1    - LONGITUDE OF LOWER LEFT CORNER OF GRID (POINT (1,1))
 C                ALL REAL*4
 C     ALATIN   - THE LATITUDE AT WHICH THE MERCATOR CYLINDER
 C                INTERSECTS THE EARTH
 C     DX       - MESH LENGTH OF GRID IN METERS AT ALATIN
 C
 C   OUTPUT ARGUMENT LIST:
 C     XI       - I COORDINATE OF THE POINT SPECIFIED BY ALAT, ALON
 C     XJ       - J COORDINATE OF THE POINT; BOTH REAL*4
 C
 C   REMARKS: FORMULAE AND NOTATION LOOSELY BASED ON HOKE, HAYES,
 C     AND RENNINGER'S "MAP PROJECTIONS AND GRID SYSTEMS...", MARCH 1981
 C     AFGWC/TN-79/003
 C
 C ATTRIBUTES:
 C   LANGUAGE: CRAY CFT77 FORTRAN
 C   MACHINE:  CRAY Y-MP8/832
 C
 C$$$
 C
 */
  rerth = 6.3712E+6;
  pi = 3.1416;

  /* C
 C        PRELIMINARY VARIABLES AND REDIFINITIONS
 C */

  radpd = pi / 180.0;
  degpr = 180.0 / pi;
  clain = cos(radpd * alatin);
  dellon = dx / (rerth*clain);

  /*
C
C        GET DISTANCE FROM EQUATOR TO ORIGIN ALAT1
C */

  djeo = 0.;
  if (alat1 != 0.) {
     djeo = (log(tan(0.5*((alat1+90.0)*radpd))))/dellon;
  }

 /* this function as originally written doesn't account for negative degrees of east latitude - JAH */
  if (alon < 0) {
    alon = alon + 360;
  }
  
  /* C
C        NOW THE I AND J COORDINATES
C */
 
/* For some reason this extra grid point causes problems, may be a Fortran relic - JAH 
  *pxi = 1. + ((alon-alon1)/(dellon*degpr));
  *pxj = 1. + (log(tan(0.5*((alat+90.0)*radpd))))/dellon-djeo;
*/
  *pxi = ((alon-alon1)/(dellon*degpr));
  *pxj = (log(tan(0.5*((alat+90.0)*radpd))))/dellon-djeo;

}
