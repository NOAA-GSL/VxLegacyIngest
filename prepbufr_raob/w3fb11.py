#!/usr/bin/python
import math
#
# this returns lower left corner to be xi = 1, xj = 1;
#
# converted from C by WRM 31-Aug-2005
#
#  88-11-25  original author:  stackpole, w/nmc42

def w3fb11(alat,elon,alat1,elon1,dx,elonv,alatan):
  
    rerth =6.3712e+6;
    pi = 3.14159;

    # h = 1 for northern hemisphere; = -1 for southern
    if(alatan > 0):
	h = 1.;
    else:
	h = -1.;
  
    radpd = pi/180.0;
    rebydx = rerth/dx;
    alatn1 = alatan * radpd;
    an = h * math.sin(alatn1);
    cosltn = math.cos(alatn1);

    # make sure that input longitudes do not pass through
    # the cut zone (forbidden territory) of the flat map
    # as measured from the vertical (reference) longitude.
    
    elon1L = elon1;
    if((elon1 - elonv) > 180.):
	elon1L = elon1 - 360.;

    if((elon1 - elonv) < (-180.)):
	elon1L = elon1 + 360.;
    
    elonL = elon;
    if((elon  - elonv) > 180.):
	elonL  = elon  - 360.;

    if((elon - elonv) < (-180.)):
	elonL = elon + 360.;
    
    elonvr = elonv *radpd;

    #  radius to lower left hand (ll) corner
    ala1 =  alat1 * radpd;
    rmLL = rebydx * (cosltn**(1.-an))*((1.+an)**an) *\
	((math.cos(ala1)/(1.+h*math.sin(ala1)))**an)/an;

    #  use ll point info to locate pole point
    elo1 = elon1L * radpd;
    arg = an * (elo1-elonvr);
    polei = 1. - h * rmLL * math.sin(arg);
    polej = 1. + rmLL * math.cos(arg);

    #  radius to desired point and the i j too
    ala =  alat * radpd;
    rm = rebydx * (cosltn**(1.-an)) * ((1.+an)**an) *\
	((math.cos(ala)/(1.+h*math.sin(ala)))**an)/an;

    elo = elonL * radpd;
    arg = an*(elo-elonvr);
    xi = polei + h * rm * math.sin(arg);
    xj = polej - rm * math.cos(arg);
    
    return (xi,xj);
