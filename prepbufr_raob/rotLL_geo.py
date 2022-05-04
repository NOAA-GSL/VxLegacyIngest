#!/usr/bin/python
import math

# adapted from rotLL_geo.c

def rotLL_geo_to_ij( lat_g_deg, lon_g_deg, lat_0_deg, lon_0_deg,
		      lat_g_SW_deg, lon_g_SW_deg, dxy_km):

    # this has been tested for the RR development version of Sept 2010l
    # I used the radius of the earth that relates the RR_devel grid spacing in km
    # to the grid spacing in degrees in the rotated system (which is the critical variable)
    # this had better be tested for other rotated LL grids!
    # THIS WAS TESTED ON 23-FEB-2017 AGAINST THE IJ PROVIDED BY
    # jet:~amb-verif/acars_TAM/grid_test.ncl with a current RAP file (using the new RotLL grid)
    # and the ij agreed to the nearest integer.

  PI = math.acos(-1);
  D2R = PI/180.;
  rearth = 6370.;		# this seems to be what works, although it ain't used elsewhere
  d_lon_r_per_cell = math.asin(dxy_km/rearth)/D2R;
  d_lat_r_per_cell = math.asin(dxy_km/rearth)/D2R;

  (lat_r_deg,lon_r_deg) = rotLL_geo_to_rot(lat_g_deg,lon_g_deg,lat_0_deg,lon_0_deg);
  (lat_r_SW_deg,lon_r_SW_deg) = rotLL_geo_to_rot(lat_g_SW_deg,lon_g_SW_deg,lat_0_deg,lon_0_deg);
  xi = (lon_r_deg - lon_r_SW_deg)/d_lon_r_per_cell;
  yj = (lat_r_deg - lat_r_SW_deg)/d_lat_r_per_cell;
  return(xi+1,yj+1)             # 1-based for use with generate_regions.py

def rotLL_geo_to_rot( lat_g_deg, lon_g_deg, lat_0_deg, lon_0_deg):
		      
    # THIS ASSUMES THAT THE CENTRAL MERIDAN POINTS NORTH (as it apparently does,
    # in spite of the value of POLE_LON in the grid definition)
    # input: geogrphic lat,lon, in degrees
    # output: geographic origin of rotated system, in degrees:

  PI = math.acos(-1);
  D2R = PI/180.;
  lat_g = lat_g_deg * D2R;
  lon_g = lon_g_deg * D2R;
  lat_0 = lat_0_deg * D2R;
  lon_0 = lon_0_deg * D2R;
  # from http://www.emc.ncep.noaa.gov/mmb/research/FAQ-eta.html#rotatedlatlongrid (2022: no longer there)
  X = math.cos(lat_0) *  math.cos(lat_g) *  math.cos(lon_g - lon_0) + math.sin(lat_0) *  math.sin(lat_g);
  Y = math.cos(lat_g) *  math.sin(lon_g - lon_0);
  Z = - math.sin(lat_0) *  math.cos(lat_g) *  math.cos(lon_g - lon_0) + math.cos(lat_0) *  math.sin(lat_g);
  lat_r = math.atan(Z / math.sqrt(math.pow(X,2) + math.pow(Y,2)) );
  lon_r = math.atan (Y / X );
  if(X < 0):
      lon_r += PI;
  if(lon_r > PI):
      lon_r -= 2*PI;
  if(lon_r < -PI):
      lon_r += 2*PI;
  lat_r_deg = lat_r/D2R;
  lon_r_deg = lon_r/D2R;
  return(lat_r_deg,lon_r_deg)
  