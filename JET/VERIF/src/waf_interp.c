/***************************************************************************************************
waf_interp.c

This program reads the NetCDF4 WAF grid, then interpolates from the native grid to the Lat/Lon grid,
(using interp_fcns.c) and finally outputs in NetCDF3 the interpolated grid.

By: Patrick Hofmann
Last Update: 02 MAY 2011
***************************************************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <cproj.h>
#include <netcdf.h>
#include <wafgrid.h>
#include <ncwdgrid.h>

void handle_error(int status);

int main( int argc, char** argv ) 
{ 
  char *inFileName   = argv[1]; //"/lfs0/projects/wrfruc/phofmann/verif/gctpc/20110404T200000Z.nc";
  char *outFileName  = argv[2]; //"/lfs0/projects/wrfruc/phofmann/verif/gctpc/waf_latlon.nc";
  char *initialTime  = argv[3]; //2011040420
  char *validTime    = argv[4]; //2011040420
  char *forecastHr   = argv[5]; //00
  
  // Get forecast hour from command line
  int t = atoi(argv[5])*4; //0

  double centerLat_rad = ( PI / 180. ) * CENTER_LAT_DEG;
  double centerLon_rad = ( PI / 180. ) * CENTER_LON_DEG;
  
  char *title = "Enroute WAF, 29KFT";

  size_t x, y;
  
  int i, j, interp_status;
  int xid, yid, ncid, waf_id, lon_id, lat_id;
  int status[20], waf_dimids[2];

  float WAF_native[NT][NY][NX];
  float WAF_interp[NLAT][NLON];
  
  static size_t start_in[4]     = {0, 0, 0, 0};
  static size_t count_in[4]     = {NT, NZ, NY, NX};
  static ptrdiff_t stride_in[4] = {1, 1, 1, 1};
  static ptrdiff_t imap_in[4]   = {NY*NX, NY*NX, NX, 1};

  static size_t start_out[2]     = {0, 0};
  static size_t count_out[2]     = {NLAT, NLON};
  static ptrdiff_t stride_out[2] = {1, 1};
  static ptrdiff_t imap_out[2]   = {NLON, 1};

  float mval = MISSING_VALUE;

  double swlat = SW_CORNER_LAT, swlon = SW_CORNER_LON;
  double nelat = NE_CORNER_LAT, nelon = NE_CORNER_LON;
  double dlat = LAT_GRID_SPACING, dlon = LON_GRID_SPACING;  
  
  // Read input field
  // -----------------------------------------------------------------------------
  printf("Reading WAF file: %s\n",inFileName);

  status[0] = nc_open(inFileName,NC_NOWRITE,&ncid);

  status[1] = nc_inq_varid(ncid,"EnrouteWAF",&waf_id);

  status[2] = nc_get_varm_float(ncid,waf_id,start_in,count_in,stride_in,imap_in,WAF_native);
  
  status[3] = nc_close(ncid);

  for (i=0;i<4;i++) {
    if (status[i] != NC_NOERR) {
      printf("Error reading WAF file\n");
      printf("status[%d] = ",i);
      handle_error(status[i]);
    }
  }

  for(i=0; i<NX; i++) {
    for(j=0; j<NY; j++) {
      if(isnan(WAF_native[t][j][i])) WAF_native[t][j][i] = 0;
      if(WAF_native[t][j][i] == -1.) WAF_native[t][j][i] = 0;
    }
  }
  
  // Interpolate grid
  // -----------------------------------------------------------------------------
  // Initialize Lambert Azimuthal Equal Area routines
  lamazforint(EARTH_RADIUS_SPEREICAL_M, centerLon_rad, centerLat_rad, FALSE_EASTING_M, FALSE_NORTHING_M);

  // Perform Neighbor-Budget Interpolation
  if (interp_status = nb_avg_interp(t,WAF_native,WAF_interp) != OK) {
    printf("Error interpolating grid\n");
  }

  // Write output interpolated grid 
  // -----------------------------------------------------------------------------
  printf("Writing interpolated WAF file: %s\n",outFileName);
  status[0]  = nc_create(outFileName,NC_CLASSIC_MODEL,&ncid);

  status[1]  = nc_def_dim(ncid,"Lat",NLAT,&lat_id);

  status[2]  = nc_def_dim(ncid,"Lon",NLON,&lon_id);

  waf_dimids[0] = lat_id;
  waf_dimids[1] = lon_id;

  status[3]  = nc_def_var(ncid,"WAF",NC_FLOAT,2,waf_dimids,&waf_id);

  status[4]  = nc_put_att(ncid,waf_id,"_FillValue",NC_FLOAT,1,&mval);

  status[5]  = nc_put_att(ncid,NC_GLOBAL,"title",NC_CHAR,strlen(title),title);

  status[6]  = nc_put_att(ncid,NC_GLOBAL,"MapProjection",NC_CHAR,strlen(MAPPROJ),MAPPROJ);

  status[7]  = nc_put_att(ncid,NC_GLOBAL,"SWCornerLat",NC_DOUBLE,1,&swlat);

  status[8]  = nc_put_att(ncid,NC_GLOBAL,"SWCornerLon",NC_DOUBLE,1,&swlon);

  status[9]  = nc_put_att(ncid,NC_GLOBAL,"NECornerLat",NC_DOUBLE,1,&nelat);

  status[10] = nc_put_att(ncid,NC_GLOBAL,"NECornerLon",NC_DOUBLE,1,&nelon);

  status[11] = nc_put_att(ncid,NC_GLOBAL,"LatGridSpacing",NC_DOUBLE,1,&dlat);

  status[12] = nc_put_att(ncid,NC_GLOBAL,"LonGridSpacing",NC_DOUBLE,1,&dlon);

  status[13] = nc_put_att(ncid,NC_GLOBAL,"InitialTime",NC_CHAR,strlen(initialTime),initialTime);

  status[14] = nc_put_att(ncid,NC_GLOBAL,"ValidTime",NC_CHAR,strlen(validTime),validTime);

  status[15] = nc_put_att(ncid,NC_GLOBAL,"ForecastHr",NC_CHAR,strlen(forecastHr),forecastHr);

  status[16] = nc_enddef(ncid);  /*leave define mode*/

  status[17] = nc_put_varm_float(ncid,waf_id,start_out,count_out,stride_out,imap_out,WAF_interp);

  status[18] = nc_close(ncid);

  for (i=0;i<19;i++) {
    if (status[i] != NC_NOERR) {
      printf("Error writing interpolated WAF file\n");
      printf("status[%d] = ",i);
      handle_error(status[i]);
    }
  }
  exit( EXIT_SUCCESS );
}

//*************************************************************************************************

void handle_error(int status)
{
  if (status != NC_NOERR) {
    printf("%s\n", nc_strerror(status));
    exit(EXIT_FAILURE);
  }
}
