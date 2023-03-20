#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>

void w3fb07(float xi, float xj,float alat1,float alon1,
            float dx, float alonv,float *alat, float *alon) 
{
  /*c       SUBROUTINE W3FB07(XI,XJ,ALAT1,ALON1,DX,ALONV,ALAT,ALON)
C$$$   SUBPROGRAM  DOCUMENTATION  BLOCK
C
C SUBPROGRAM:  W3FB07        GRID COORDS TO LAT/LON FOR GRIB
C   PRGMMR: STACKPOLE        ORG: NMC42       DATE:88-04-05
C
C ABSTRACT: CONVERTS THE COORDINATES OF A LOCATION ON EARTH GIVEN IN A
C   GRID COORDINATE SYSTEM OVERLAID ON A POLAR STEREOGRAPHIC MAP PRO-
C   JECTION TRUE AT 60 DEGREES N OR S LATITUDE TO THE
C   NATURAL COORDINATE SYSTEM OF LATITUDE/LONGITUDE
C   W3FB07 IS THE REVERSE OF W3FB06.
C   USES GRIB SPECIFICATION OF THE LOCATION OF THE GRID
C
C PROGRAM HISTORY LOG:
C   88-01-01  ORIGINAL AUTHOR:  STACKPOLE, W/NMC42
C   90-04-12  R.E.JONES   CONVERT TO CRAY CFT77 FORTRAN
C
C USAGE:  CALL W3FB07(XI,XJ,ALAT1,ALON1,DX,ALONV,ALAT,ALON)
C   INPUT ARGUMENT LIST:
C     XI       - I COORDINATE OF THE POINT  REAL*4
C     XJ       - J COORDINATE OF THE POINT  REAL*4
C     ALAT1    - LATITUDE  OF LOWER LEFT POINT OF GRID (POINT 1,1)
C                LATITUDE <0 FOR SOUTHERN HEMISPHERE; REAL*4
C     ALON1    - LONGITUDE OF LOWER LEFT POINT OF GRID (POINT 1,1)
C                  EAST LONGITUDE USED THROUGHOUT; REAL*4
C     DX       - MESH LENGTH OF GRID IN METERS AT 60 DEG LAT
C                 MUST BE SET NEGATIVE IF USING
C                 SOUTHERN HEMISPHERE PROJECTION; REAL*4
C                   190500.0 LFM GRID,
C                   381000.0 NH PE GRID, -381000.0 SH PE GRID, ETC.
C     ALONV    - THE ORIENTATION OF THE GRID.  I.E.,
C                THE EAST LONGITUDE VALUE OF THE VERTICAL MERIDIAN
C                WHICH IS PARALLEL TO THE Y-AXIS (OR COLUMNS OF
C                THE GRID) ALONG WHICH LATITUDE INCREASES AS
C                THE Y-COORDINATE INCREASES.  REAL*4
C                   FOR EXAMPLE:
C                   255.0 FOR LFM GRID,
C                   280.0 NH PE GRID, 100.0 SH PE GRID, ETC.
C
C   OUTPUT ARGUMENT LIST:
C     ALAT     - LATITUDE IN DEGREES (NEGATIVE IN SOUTHERN HEMI.)
C     ALON     - EAST LONGITUDE IN DEGREES, REAL*4
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
      double rerth,pi,radpd,rebydx,alatn1,an,cosltn,elon1L,elonL,elonvr;
      double ala1,rmll,elo1,arg,polei,polej,ala,rm,elo,h,ss60;
      double beta,piby2,xx,yy,r2,aninv,aninv2,degprd,theta;
      double reflon,dxl,alo1,gi2,arccos;
      /* CHANGE XI AND XJ TO 1-BASED RATHER THAN 0 BASED, FOR USE HERE*/
      xi++;
      xj++;

      rerth =6.3712e+6;
      pi=3.14159;
      ss60 = 1.86603;

      /*C
C        PRELIMINARY VARIABLES AND REDIFINITIONS
C
C        H = 1 FOR NORTHERN HEMISPHERE; = -1 FOR SOUTHERN
C
C        REFLON IS LONGITUDE UPON WHICH THE POSITIVE X-COORDINATE
C        DRAWN THROUGH THE POLE AND TO THE RIGHT LIES
C        ROTATED AROUND FROM ORIENTATION (Y-COORDINATE) LONGITUDE
C        DIFFERENTLY IN EACH HEMISPHERE
C */
         if (dx < 0) {
           h      = -1.0;
           dxl    = -dx;
           reflon = alonv - 90.0;
         }
         else{
           h      = 1.0;
           dxl    = dx;
           reflon = alonv - 270.0;
         }

         radpd  = pi    / 180.0;
         degprd = 180.0 / pi;
         rebydx = rerth / dxl;

	 /*C
C        RADIUS TO LOWER LEFT HAND (LL) CORNER
C */
         ala1 = alat1 * radpd;
         rmll = rebydx  * cos(ala1) * ss60/(1. + h * sin(ala1));

	 /*C
C        USE LL POINT INFO TO LOCATE POLE POINT
C */

         alo1 = (alon1 - reflon) * radpd;
         polei = 1. - rmll * cos(alo1);
         polej = 1. - h* rmll * sin(alo1);

/*C
C        RADIUS TO THE I,J POINT (IN GRID UNITS)
C  */
         xx =  xi - polei ;
	 yy = (xj - polej) * h;
	 r2 =  pow(xx,2) + pow(yy,2); 


	   /*C
C        NOW THE MAGIC FORMULAE
C */

	  if (r2 == 0) {
           *alat = h * 90.;
           *alon = reflon;
           } 
	  else{
           gi2    = pow((rebydx * ss60 ),2);
           *alat = degprd * h *asin((gi2-r2)/(gi2+r2));
           arccos = acos(xx/sqrt(r2));
	    if (yy > 0) { 
             *alon = reflon + degprd * arccos; 
             }
	    else {
             *alon = reflon - degprd * arccos;
             }
          }

	  if (*alon < 0) {
           *alon = *alon +360.;
	   } 
}


