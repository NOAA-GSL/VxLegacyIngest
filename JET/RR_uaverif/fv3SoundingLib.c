#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#define MISSING 99999

/**********************************************************************/
void dewpoint(float p, float vpt, float qv, float *pt, float *ptd) {
  /* ;;returns dewpoint in kelvin,
     ;; given pressure in pascals, virtual potential temp in kelvin
     ;; and water vapor mixing ratio in g/g
     */

  double esw_pascals,e_pascals,log10_e,dewpoint;
  double exnr,cpd_p,rovcp_p,pol,rh,q;
  double tk,tx,e,exner;

  cpd_p=1004.686;
  rovcp_p=0.285714;             /* R/cp */
  exner = cpd_p*pow((p/100000.),rovcp_p);
  q = qv/(1.+qv);
  tk = vpt*exner/(cpd_p*(1.+0.6078*q));

  /*
  printf("p: %f vpt: %f qv: %f exner: %f, q: %f tk:%f \n",
         p,vpt,qv,exner,q,tk);
  */

  /* Stan's way of calculating sat vap pressure:
  tx = tk-273.15;
  pol = 0.99999683       + tx*(-0.90826951e-02 +
      tx*(0.78736169e-04   + tx*(-0.61117958e-06 +
      tx*(0.43884187e-08   + tx*(-0.29883885e-10 +
      tx*(0.21874425e-12   + tx*(-0.17892321e-14 +
      tx*(0.11112018e-16   + tx*(-0.30994571e-19)))))))));
  esw_old_pascals = 6.1078/pow(pol,8.) *100.;
  */

  /* Rex's way of calculating sat vap pressure: */
  /* From Fan and Whiting (1987) as quoted in Fleming (1996): BAMS 77, p
     2229-2242, the saturation vapor pressure is given by: */
  esw_pascals=pow(10.,((10.286*tk - 2148.909)/(tk-35.85)));
  e = p*qv/(0.62197+qv);
  rh = e/esw_pascals;


  e_pascals = rh*esw_pascals;
  log10_e = log10(e_pascals);

  /* invert the formula for esw to see the temperature at which
     e is the saturation value */

  dewpoint = (float)((-2148.909 + 35.85*log10_e)/(-10.286 + log10_e));
  *pt = tk;
  *ptd = dewpoint;
}

void get_ij(float alat,float elon, float ddeg, float *pxi,float *pxj) {
  if(elon < 0) {
    elon += 360;
  }
  /* we:sn scan */
  *pxi = elon * 4.0;
  *pxj = (90+alat) * 4.0;


   /* Bill's fix */
  /* 
   *pxi = elon/ddeg;
   *pxj = (90-alat)/ddeg;
   */
}

void get_ll(float startx,float starty,float ddeg, float *grid_lat,float *grid_lon) {
  *grid_lon = startx*ddeg;
  if(*grid_lon > 180) {
    *grid_lon -=360;
  }
  /* Bill's fix  */
/*  *grid_lat = 90.0 - (starty * ddeg); */

  *grid_lat = (starty * ddeg) - 90.0;
}


time_t makeSecs(int year, int julday, int hour) {
/* makes number of secs since 1970 from an atime.  see p 111 of
 kernighan and Richie, 2nd ed.
 */
  struct tm tm;
  struct tm *tp;
  static int daytab[2][13] = {
    {0,31,28,31,30,31,30,31,31,30,31,30,31},
    {0,31,29,31,30,31,30,31,31,30,31,30,31}
  };
  time_t timet;
  int i,leap;

  /* get tp to point to the tm structure */
  tp=&tm;

  tp->tm_sec=0;
  tp->tm_min=0;
  tp->tm_hour=hour;
  tp->tm_year = year-1900;

  /* get month and day from julian day */
  leap = (year%4 == 0 && year%100 != 0) || year%400 == 0;
  for(i=1;julday>daytab[leap][i];i++)
    julday -= daytab[leap][i];

  tp->tm_mon = i-1;             /* months should start at zero */
  tp->tm_isdst = -1;            /* flag to calculate dst */
  tp->tm_mday = julday;         /* it is now just the left-over days */
  timet = mktime(tp);
  return timet;
}

/*  this function uses a saturation vapor pressure over
c   liquid water formula. the formula appears
c   in Bolton, David, 1980: "The Computation of Equivalent Potential
C   Temperature," Monthly Weather Review, Vol. 108, No. 7 (July),
c   p. 1047, eq.(10). the quoted accuracy is 0.3% or better for
c   -35 < t < 35c.

c   temperatures are in K
c   rh is between 0 and 1

C  for temperatures of down to -60 C, rh values
C  calculated from this formula differ from those
C  calculated by Goff-Gratsch by < .05 %RH  - WRM 16 May 2008

C  Baker, Schlatter  17-MAY-1982 (Original version).
C  Inverted to give dewpoint from t and rh by Moninger, 8-July-2008
  */

float tdBolton(float tk, float rh) {
  float result = MISSING;
  if(rh < MISSING -1 &&
     rh >= 0.0001) {
    double tc = tk-273.15;
    // printf ("rh: %f tk: %f tc: %f\n",rh,tk,tc);
    // get svp (mb) at tk
    double esw_mb;
    //esw_mb = 6.1121 * Math.exp(17.67*tc/(tc+243.5));
    esw_mb = 6.1121 * exp(17.67*tc/(tc+243.5));
    double e_mb = rh*esw_mb;
    // printf ("esw_mb: %f e_mb: %f\n",esw_mb,e_mb);
    // note that dewpoint is the tempreature at which e_mb = saturation
    // get this by inverting the Bolton forumua.
    // double fact = Math.log(e_mb/6.1121);
    double fact = log(e_mb/6.1121);
    double tdc = fact * 243.5 /(17.67 - fact);
    result = (float)(tdc + 273.15);
    // printf ("fact: %f tdc: %f result: %f\n",fact,tdc,result);
  }
  return(result);
} 
