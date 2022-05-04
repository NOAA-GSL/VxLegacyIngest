#!/usr/bin/python
import sys
import os
from string import *
import time
import re
import math
import operator
from w3fb11 import w3fb11
from w3fb06 import w3fb06
from rotLL_geo import rotLL_geo_to_ij

def gen_regions(wmoid,name,lat,lon):
    reg = []
    # calculate regions. Do the easy ones first
    # global
    reg.append('7')
    # tropics
    if abs(lat) <= 20:
        reg.append('8')
    # southern extratropics
    if lat >= -80 and lat < 20:
        reg.append('9')
    # Northern extratropics
    if lat > 20 and lat <= 80:
        reg.append('10')
    # Arctic
    if lat >= 70:
        reg.append('11')
    # Antarctic
    if lat <= -70:
        reg.append('12')
    # West of 109W longitude
    if lon < -109:
        reg.append('17')
    else:
    # East of 109W longitude
        reg.append('18')
    # Hawaii
    if lat >= 15     and lat  <= 30 and \
       lon >= -170 and lon <= -140:
        reg.append('19')
    #Alaska (hardwire for now)
    #alaska_wmoids = [70026,70133,70200,70219,70231,70261,70273,70308,70316,70326,70350,70361,70398,70414]
    #if wmoid in alaska_wmoids:
    # AK
    alat1 = 41.612949
    elon1 = 185.117126
    dx = 3000.000000
    elonv = 225.000000
    alatan = 60.000000
    nx = 1299
    ny = 919
    (x,y) = w3fb06(lat,lon,alat1,elon1,dx,elonv,alatan)
    if x <=nx and x >= 1 and y < ny and y >= 1:
        #print("AK:  {} {}: {} {} {:.2f} {:.2f}".format(wmoid,name,lat,lon,x,y))
        reg.append('13')
        
    # HRRR
    alat1 = 21.138;
    elon1 = 237.28;
    dx = 3000;
    elonv =262.5;
    alatan = 38.5;
    nx = 1799;
    ny = 1059;
    (x,y) = w3fb11(lat,lon,alat1,elon1,dx,elonv,alatan)
    if x <=nx and x >= 1 and y < ny and y >= 1:
        #print("IN HRRR {:.0f},{:.0f}".format(float(hrrr_xy[0]),float(hrrr_xy[1])))
        reg.append('14')
    # RUC (40 km) domain
    alat1=16.281;
    elon1=233.862198;
    dx=40635.25;
    elonv=265.;
    alatan=25.;
    nx=151
    ny = 113
    (x,y) = w3fb11(lat,lon,alat1,elon1,dx,elonv,alatan)
    if x <=nx and x >= 1 and y < ny and y >= 1:
        #print("IN RUC {:.0f},{:.0f}".format(float(ruc_xy[0]),float(ruc_xy[1])))
        reg.append('0')
        
    # RR region (grid_type 21)
    lat_0_deg = 54.0;
    lon_0_deg = -106.0;
    lat_g_SW_deg =  -10.5906;
    lon_g_SW_deg = -139.0858;
    dxyLL = 13.54508;
    nx = 953;
    ny = 834;
    (x,y) = rotLL_geo_to_ij( lat,lon,lat_0_deg, lon_0_deg,lat_g_SW_deg, lon_g_SW_deg, dxyLL)
    #print("RR: {} {}: {} {} {:.2f} {:.2f}".format(wmoid,name,lat,lon,x,y))
    if x <=nx and x >= 1 and y < ny and y >= 1:
        reg.append('6')
   
    dups_removed = list(set(reg))
    dups_removed.sort(key=int)
    reg_list = ",".join(dups_removed)

    return(reg_list)
