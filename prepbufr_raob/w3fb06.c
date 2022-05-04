#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>


void w3fb06(float alat,float alon,float alat1,float alon1,float dx,float alonv ,float *pxi, float *pxj)
{

  double rerth,pi,radpd,rebydx,alatn1,an,cosltn,elon1L,elonL,elonvr;
  double ala1,rmll,elo1,arg,polei,polej,ala,rm,elo,h;
  double ss60,dxl,reflon,alo1,alo;


  /*  C$$$   SUBPROGRAM  DOCUMENTATION  BLOCK
C
C SUBPROGRAM:  W3FB06        LAT/LON TO POLA (I,J) FOR GRIB
C   PRGMMR: STACKPOLE        ORG: NMC42       DATE:88-04-05
C
C ABSTRACT: CONVERTS THE COORDINATES OF A LOCATION ON EARTH GIVEN IN
C   THE NATURAL COORDINATE SYSTEM OF LATITUDE/LONGITUDE TO A GRID
C   COORDINATE SYSTEM OVERLAID ON A POLAR STEREOGRAPHIC MAP PRO-
C   JECTION TRUE AT 60 DEGREES N OR S LATITUDE. W3FB06 IS THE REVERSE
C   OF W3FB07. USES GRIB SPECIFICATION OF THE LOCATION OF THE GRID
C
C PROGRAM HISTORY LOG:
C   88-01-01  ORIGINAL AUTHOR:  STACKPOLE, W/NMC42
C   90-04-12  R.E.JONES   CONVERT TO CRAY CFT77 FORTRAN
C
C USAGE:  CALL W3FB06 (ALAT,ALON,ALAT1,ALON1,DX,ALONV,XI,XJ)
C   INPUT ARGUMENT LIST:
C     ALAT     - LATITUDE IN DEGREES (NEGATIVE IN SOUTHERN HEMIS)
C     ALON     - EAST LONGITUDE IN DEGREES, REAL*4
C     ALAT1    - LATITUDE  OF LOWER LEFT POINT OF GRID (POINT (1,1))
C     ALON1    - LONGITUDE OF LOWER LEFT POINT OF GRID (POINT (1,1))
C                ALL REAL*4
C     DX       - MESH LENGTH OF GRID IN METERS AT 60 DEG LAT
C                 MUST BE SET NEGATIVE IF USING
C                 SOUTHERN HEMISPHERE PROJECTION.
C                   190500.0 LFM GRID,
C                   381000.0 NH PE GRID, -381000.0 SH PE GRID, ETC.
C     ALONV    - THE ORIENTATION OF THE GRID.  I.E.,
C                THE EAST LONGITUDE VALUE OF THE VERTICAL MERIDIAN
C                WHICH IS PARALLEL TO THE Y-AXIS (OR COLUMNS OF
C                OF THE GRID)ALONG WHICH LATITUDE INCREASES AS
C                THE Y-COORDINATE INCREASES.  REAL*4
C                   FOR EXAMPLE:
C                   255.0 FOR LFM GRID,
C                   280.0 NH PE GRID, 100.0 SH PE GRID, ETC.
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
C */
  rerth = 6.3712E+6;
  pi = 3.1416;
  ss60=  1.86603;
	   /*C
C        PRELIMINARY VARIABLES AND REDIFINITIONS
C
C        H = 1 FOR NORTHERN HEMISPHERE; = -1 FOR SOUTHERN
C
C        REFLON IS LONGITUDE UPON WHICH THE POSITIVE X-COORDINATE
C        DRAWN THROUGH THE POLE AND TO THE RIGHT LIES
C        ROTATED AROUND FROM ORIENTATION (Y-COORDINATE) LONGITUDE
C        DIFFERENTLY IN EACH HEMISPHERE
C  */
	   if (dx < 0) {
	     h      = -1.0;
	     dxl     = -dx;
	     reflon = alonv  - 90.0;}
           else {
	     h      = 1.0;
	     dxl    = dx;
	     reflon = alonv - 270.0;}

	   radpd  = pi / 180.0;
	   rebydx = rerth/dxl;

	   /* C        RADIUS TO LOWER LEFT HAND (LL) CORNER */

	   ala1 = alat1  * radpd; 
	   rmll = rebydx * cos(ala1) * ss60/(1. + h * sin(ala1));

	   /*C        USE LL POINT INFO TO LOCATE POLE POINT*/

	   alo1   = (alon1 - reflon) * radpd ;
	   polei  = 1. - rmll  * cos(alo1);
	   polej  = 1. - h * rmll * sin(alo1);

	   /*C        RADIUS TO DESIRED POINT AND THE I J TOO */

	   ala = alat * radpd ;
	   rm  = rebydx * cos(ala) * ss60/(1. + h * sin(ala));

	   alo = (alon - reflon) * radpd ;
	   *pxi  = polei  + rm  * cos(alo);
	   *pxj  = polej + h * rm * sin(alo);
	   *pxi -= 1;
	   *pxj -= 1;

	   /*	   printf("xue lat (radians) is %f\n",alat);
	   printf("xue lon (radians) is %f\n",alon);
	   printf("xue pxi (0-based) is %f\n",*pxi);
	   printf("xue pxj (0-based) is %f\n",*pxj);*/


	 }

