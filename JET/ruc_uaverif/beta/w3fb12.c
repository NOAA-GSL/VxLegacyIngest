#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

void w3fb12(float xi,float xj,float alat1,float elon1,
	    float dx,float elonv,float alatan,
	    float *alat,float *elon)
{
  double rerth,pi,radpd,rebydx,alatn1,an,cosltn,elon1L,elonL,elonvr;
  double ala1,rmLL,elo1,arg,polei,polej,ala,rm,elo,h;
  double beta,piby2,xx,yy,r2,aninv,aninv2,thing,degprd,theta;

/*c$$$   subprogram  documentation  block

  THIS NOW expects XI AND YJ REFERENCED TO (0,0) INSTEAD OF (1,1)!
c
c subprogram:  w3fb12        lambert(i,j) to lat/lon for grib
c   prgmmr: stackpole        org: nmc42       date:88-11-28
c
c abstract: converts the coordinates of a location on earth given in a
c   grid coordinate system overlaid on a lambert conformal tangent
c   cone projection true at a given n or s latitude to the
c   natural coordinate system of latitude/longitude
c   w3fb12 is the reverse of w3fb11.
c   uses grib specification of the location of the grid
c
c program history log:
c   88-11-25  original author:  stackpole, w/nmc42
c
c usage:  call w3fb12(xi,xj,alat1,elon1,dx,elonv,alatan,alat,elon,ierr,
c                                   ierr)
c   input argument list:
c     xi       - i coordinate of the point  real*4
c     xj       - j coordinate of the point  real*4
c     alat1    - latitude  of lower left point of grid (point 1,1)
c                latitude <0 for southern hemisphere; real*4
c     elon1    - longitude of lower left point of grid (point 1,1)
c                  east longitude used throughout; real*4
c     dx       - mesh length of grid in meters at tangent latitude
c     elonv    - the orientation of the grid.  i.e.,
c                the east longitude value of the vertical meridian
c                which is parallel to the y-axis (or columns of
c                the grid) along which latitude increases as
c                the y-coordinate increases.  real*4
c                this is also the meridian (on the other side of the
c                tangent cone) along which the cut is made to lay
c                the cone flat.
c     alatan   - the latitude at which the lambert cone is tangent to
c                (touches or osculates) the spherical earth.
c                 set negative to indicate a
c                 southern hemisphere projection; real*4
c
c   output argument list:
c     alat     - latitude in degrees (negative in southern hemi.)
c     elon     - east longitude in degrees, real*4
c     ierr     - .eq. 0   if no problem
c                .ge. 1   if the requested xi,xj point is in the
c                         forbidden zone, i.e. off the lambert map
c                         in the open space where the cone is cut.
c                  if ierr.ge.1 then alat=999. and elon=999.
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
  /* CHANGE XI AND XJ TO 1-BASED RATHER THAN 0 BASED, FOR USE HERE*/
  xi++;
  xj++;
  
  rerth =6.3712e+6;
  pi=3.14159;
/*c
c        preliminary variables and redifinitions
c
c        h = 1 for northern hemisphere; = -1 for southern
c*/
  beta  = 1.;

  if(alatan > 0) {
    h = 1.;
  } else {
    h = -1.;
  }
  
  piby2 = pi/2.;
  radpd = pi/180.0;
  degprd = 1./radpd;
  rebydx = rerth/dx;
  alatn1 = alatan * radpd;
  an = h * sin(alatn1);
  cosltn = cos(alatn1);
  /*c
    c        make sure that input longitude does not pass through
    c        the cut zone (forbidden territory) of the flat map
    c        as measured from the vertical (reference) longitude
    c*/
  elon1L = elon1;
  if((elon1 - elonv) > 180.) {
    elon1L = elon1 - 360.;
  }
  if((elon1 - elonv) < (-180.)) {
    elon1L = elon1 + 360.;
  }

  elonL = *elon;
  if((*elon  - elonv) > 180.) {
     elonL  = *elon  - 360.;
  }
  if((*elon - elonv) < (-180.)) {
    elonL = *elon + 360.;
  }

  elonvr = elonv * radpd;

/*c
c        radius to lower left hand (ll) corner
c*/
  ala1 =  alat1 * radpd;
  rmLL = rebydx * pow(cosltn,(1.-an))*pow((1.+an),an) *
    pow(cos(ala1)/(1.+h*sin(ala1)),an)/an;
  

/*c
c          use ll point info to locate pole point
c*/
  elo1 = elon1L * radpd;
  arg = an * (elo1-elonvr);
  polei = 1. - h * rmLL * sin(arg);
  polej = 1. + rmLL * cos(arg);
  /*c
    c        radius to the i,j point (in grid units)
    c              yy reversed so positive is down
    c*/
  xx = xi - polei;
  yy = polej - xj;
  r2 = pow(xx,2) + pow(yy,2);
  
  /*c
    c        check that the requested i,j is not in the forbidden zone
    c           yy must be positive up for this test
    c*/
  theta = pi*(1.-an);
  beta = abs(atan2(xx,-yy));
  if(beta <= theta){
    *alat = 999.;
    *elon = 999.;
  } else {
    /*c
      c        now the magic formulae
      c*/
    if(r2 == 0) {
      *alat = h * 90.;
      *elon = elonv;
    } else {
      /*c
	c          first the longitude
	c*/
      *elon = elonv + degprd * atan2(h*xx,yy)/an;
      if(*elon > 180) {
	*elon -= 360.;
      } else if(*elon < -180) {
	*elon += 360;
      }
      /*c
	c          now the latitude
	c*/
      aninv = 1./an;
      aninv2 = aninv/2.;
      thing = pow(an/rebydx,aninv)/(pow(cosltn,((1.-an)*aninv))*(1.+ an));
      *alat = h*(piby2 - 2.*atan(thing*pow(r2,aninv2)))*degprd;
    }
  }
}
