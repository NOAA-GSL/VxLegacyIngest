#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>

void w3fb11(float alat,float elon,
	    float alat1,float elon1,float dx,float elonv,float alatan,
	    float *pxi,float *pxj)
{
  double rerth,pi,radpd,rebydx,alatn1,an,cosltn,elon1L,elonL,elonvr;
  double ala1,rmLL,elo1,arg,polei,polej,ala,rm,elo,h;
  
  /* ORIGINALLY IN FORTRAN, changed to c by wrm, 2/10/98

     THIS NOW PUTS OUT XI AND YJ REFERENCED TO (0,0) INSTEAD OF (1,1)!!
     
    c$$$   subprogram  documentation  block
     c
     c subprogram:  w3fb11        lat/lon to lambert(i,j) for grib
     c   prgmmr: stackpole        org: nmc42       date:88-11-28
     c
     c abstract: converts the coordinates of a location on earth given in
     c   the natural coordinate system of latitude/longitude to a grid
     c   coordinate system overlaid on a lambert conformal tangent cone
     c   projection true at a given n or s latitude. w3fb11 is the reverse
     c   of w3fb12. uses grib specification of the location of the grid
     c
     c program history log:
     c   88-11-25  original author:  stackpole, w/nmc42
     c
     c usage:  call w3fb11 (alat,elon,alat1,elon1,dx,elonv,alatan,xi,xj)
     c   input argument list:
     c     alat     - latitude in degrees (negative in southern hemis)
     c     elon     - east longitude in degrees, real*4
     c     alat1    - latitude  of lower left point of grid (point (1,1))
     c     elon1    - longitude of lower left point of grid (point (1,1))
     c                all real*4
     c     dx       - mesh length of grid in meters at tangent latitude
     c     elonv    - the orientation of the grid.  i.e.,
     c                the east longitude value of the vertical meridian
     c                which is parallel to the y-axis (or columns of
     c                of the grid) along which latitude increases as
     c                the y-coordinate increases.  real*4
     c                this is also the meridian (on the back side of the
     c                tangent cone) along which the cut is made to lay
     c                the cone flat.
     c     alatan   - the latitude at which the lambert cone is tangent to
     c                (touching) the spherical earth.
     c                 set negative to indicate a
     c                 southern hemisphere projection.
     c
     c   output argument list:
     c     xi       - i coordinate of the point specified by alat, elon
     c     xj       - j coordinate of the point; both real*4
     c
     c   remarks: formulae and notation loosely based on hoke, hayes,
     c     and renninger's "map projections and grid systems...", march 1981
     c     afgwc/tn-79/003
     c
     c attributes:
     c   language: ibm vs fortran
     c   machine:  nas
     c
     c$$$
     c
     */
  rerth =6.3712e+6;
  pi = 3.14159;
  
  /*c
    c        preliminary variables and redifinitions
    c
    c        h = 1 for northern hemisphere; = -1 for southern
    c*/
  if(alatan > 0) {
    h = 1.;
  } else {
    h = -1.;
  }
  
  radpd = pi/180.0;
  rebydx = rerth/dx;
  alatn1 = alatan * radpd;
  an = h * sin(alatn1);
  cosltn = cos(alatn1);

  /*c
    c        make sure that input longitudes do not pass through
    c        the cut zone (forbidden territory) of the flat map
    c        as measured from the vertical (reference) longitude.
    c*/
  elon1L = elon1;
  if((elon1 - elonv) > 180.) {
    elon1L = elon1 - 360.;
  }
  if((elon1 - elonv) < (-180.)) {
    elon1L = elon1 + 360.;
  }

  elonL = elon;
  if((elon  - elonv) > 180.) {
     elonL  = elon  - 360.;
  }
  if((elon - elonv) < (-180.)) {
    elonL = elon + 360.;
  }

  elonvr = elonv *radpd;
  
  /*c
    c        radius to lower left hand (ll) corner
    c*/
  ala1 =  alat1 * radpd;
  rmLL = rebydx * pow(cosltn,(1.-an))*pow((1.+an),an) *
    pow(cos(ala1)/(1.+h*sin(ala1)),an)/an;
  
  /*c
    c        use ll point info to locate pole point
    c*/
  elo1 = elon1L * radpd;
  arg = an * (elo1-elonvr);
  polei = 1. - h * rmLL * sin(arg);
  polej = 1. + rmLL * cos(arg);
  
  /*c
    c        radius to desired point and the i j too
    c*/
  ala =  alat * radpd;
  rm = rebydx * pow(cosltn,(1.-an)) * pow((1.+an),an) *
    pow(cos(ala)/(1.+h*sin(ala)),an)/an;

  elo = elonL * radpd;
  arg = an*(elo-elonvr);
  *pxi = polei + h * rm * sin(arg);
  *pxj = polej - rm * cos(arg);
  
  /* reference to (0,0) for C, instead of (1,1) for fortran */
  *pxi -= 1;
  *pxj -= 1;
}

