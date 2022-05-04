#!/usr/bin/python
from math import cos, sin
#
# this returns lower left corner to be xi = 1, xj = 1;
#
# converted from C by WRM 1-Feb-2022
#
#  88-11-25  original author:  stackpole, w/nmc42

def w3fb06(alat,alon,alat1,alon1,dx,alonv,alatan):
    rerth = 6.3712E+6;
    pi = 3.1416;
    ss60=  1.86603;
    if (dx < 0):
        h      = -1.0;
        dxl     = -dx;
        reflon = alonv  - 90.0;
    else:
        h      = 1.0;
        dxl    = dx;
        reflon = alonv - 270.0;

    radpd  = pi / 180.0;
    rebydx = rerth/dxl;

    #	   /* C        RADIUS TO LOWER LEFT HAND (LL) CORNER */

    ala1 = alat1  * radpd; 
    rmll = rebydx * cos(ala1) * ss60/(1. + h * sin(ala1));

    #   /*C        USE LL POINT INFO TO LOCATE POLE POINT*/

    alo1   = (alon1 - reflon) * radpd ;
    polei  = 1. - rmll  * cos(alo1);
    polej  = 1. - h * rmll * sin(alo1);

    #	   /*C        RADIUS TO DESIRED POINT AND THE I J TOO */

    ala = alat * radpd ;
    rm  = rebydx * cos(ala) * ss60/(1. + h * sin(ala));

    alo = (alon - reflon) * radpd ;
    xi  = polei  + rm  * cos(alo);
    xj  = polej + h * rm * sin(alo);
    
    return(xi,xj)               # 1-based, not zero based (as in the original Fortran).
