/***************************************************************************************************
lamaz_prob_interp.c

This program reads the NetCDF4 WAF or MITLL probability grid, then interpolates from the native grid
to the Lat/Lon grid, (using interp_fcns.c) and finally outputs in NetCDF3 the interpolated grid.

By: Patrick Hofmann
Last Update: 10 MAY 2011
***************************************************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <cproj.h>
#include <netcdf.h>
#include <wafgrid.h>
#include <string.h>
#include <ncwdstruct.h>
#include <sys/types.h>

void handle_error(int status);
int grid_init(char* , GRID* );

int main( int argc, char** argv ) 
{ 
  char* inFileName   = argv[1]; //"/lfs0/projects/wrfruc/phofmann/verif/gctpc/20110404T200000Z.nc"
  char* outFileName  = argv[2]; //"/lfs0/projects/wrfruc/phofmann/verif/gctpc/llp_latlon.nc"
  char* initialTime  = argv[3]; //2011040420
  char* validTime    = argv[4]; //2011040420
  char* forecastHr   = argv[5]; //00
  char* inVarName    = argv[6]; //"ProbFcst"
  char* outVarName   = argv[7]; //"LLProb"
  char* outGrid      = argv[8]; //"ncwd_04km"
  char* radPts       = argv[9]; //3
  char* method       = argv[10]; //Interp method: NN - nearest neighbor, NBAVG - neighbor budget average, NBMAX - neighbor budget max value
  
  // Get integer forecast hour
  int32_t t = atoi(argv[5])*4;

  // Get integer radius points for interpolation
  int32_t RP = atoi(argv[9]);
  
  double centerLat_rad = ( PI / 180. ) * CENTER_LAT_DEG;
  double centerLon_rad = ( PI / 180. ) * CENTER_LON_DEG;
  
  size_t x, y;

  char title[64];
  char mittitle[] = "MITLL Probability Forecast";
  char waftitle[] = "Enroute WAF, 29KFT";
 
  char cmptitle[] = "ProbFcst";
  char cmpNN[] = "NN";
  char cmpNBAVG[] = "NBAVG";
  char cmpNBMAX[] = "NBMAX";
  
  int32_t i, j, interp_status;
  int32_t ncid, prob_id, x_id, y_id, lat_id, lon_id;
  int32_t status[25], prob_dimids[2];

  // Initialize the GRID structure for whichever output grid was specified on the command line
  GRID output_grid;
  int32_t init_status = grid_init(outGrid,&output_grid);
    
  char mapproj[64];
  strncpy(mapproj,output_grid.mapproj,strlen(output_grid.mapproj));
  int32_t nlat = output_grid.nlat;
  int32_t nlon = output_grid.nlon;
  double swlat = output_grid.swlat;
  double swlon = output_grid.swlon+360.;
  double nelat = output_grid.nelat;
  double nelon = output_grid.nelon+360.;
  double  dlat = output_grid.dlat; 
  double  dlon = output_grid.dlon;  
  float   mval = output_grid.missing_value;

  printf("mapproj = %s\n",mapproj);
  printf("nlat = %d, nlon = %d\n",nlat,nlon);
  printf("swlat = %f, swlon = %f\n",swlat,swlon);
  printf("nelat = %f, nelon = %f\n",nelat,nelon);
  printf("dlat = %f, dlon = %f\n",dlat,dlon);


  float PROB_native[NT][NY][NX];
  float** PROB_interp = NULL;
  float** lat = NULL;
  float** lon = NULL;

  // Initialize arrays for reading input field
  static size_t start_in[4]     = {0, 0, 0, 0};
  static size_t count_in[4]     = {NT, NZ, NY, NX};
  static ptrdiff_t stride_in[4] = {1, 1, 1, 1};
  static ptrdiff_t imap_in[4]   = {NY*NX, NY*NX, NX, 1};

  static size_t start_out[2]     = {0, 0};
  size_t count_out[2]            = {nlat, nlon};
  static ptrdiff_t stride_out[2] = {1, 1};
  ptrdiff_t imap_out[2]          = {nlon, 1};
  
  // =======================================CODE BEGINS================================================
  
  // Define NetCDF title attribute
  if (strncmp(inVarName,cmptitle,strlen(cmptitle)) == 0) {
    strncpy(title,mittitle,strlen(mittitle));
  } else {
    strncpy(title,waftitle,strlen(waftitle));
  }
  
  // Read input field
  // -----------------------------------------------------------------------------
  printf("Reading LamAz probability file: %s\n",inFileName);

  status[0] = nc_open(inFileName,NC_NOWRITE,&ncid);

  status[1] = nc_inq_varid(ncid,inVarName,&prob_id);

  status[2] = nc_get_varm_float(ncid,prob_id,start_in,count_in,stride_in,imap_in,**PROB_native);
  
  status[3] = nc_close(ncid);

  for (i=0;i<4;i++) {
    if (status[i] != NC_NOERR) {
      printf("Error reading LamAz probability file\n");
      printf("status[%d] = ",i);
      handle_error(status[i]);
    }
  }

  for(i=0; i<NX; i++) {
    for(j=0; j<NY; j++) {
      if(isnan(PROB_native[t][j][i])) PROB_native[t][j][i] = 0;
      if(PROB_native[t][j][i] == -1.) PROB_native[t][j][i] = mval;
    }
  }
  
  // Interpolate grid
  // -----------------------------------------------------------------------------
  // Allocate dynamic arrays
  if (alloc_2d(nlat,nlon,sizeof(float), (void***) &PROB_interp) == ERROR) {
    printf("Probability Array not allocated\n");
    return(ERROR);
  }
  if (alloc_2d(nlat,nlon,sizeof(float), (void***) &lat) == ERROR) {
    printf("Probability Array not allocated\n");
    return(ERROR);
  }
  if (alloc_2d(nlat,nlon,sizeof(float), (void***) &lon) == ERROR) {
    printf("Probability Array not allocated\n");
    return(ERROR);
  }

  // Initialize Lambert Azimuthal Equal Area routines
  lamazforint(EARTH_RADIUS_SPEREICAL_M, centerLon_rad, centerLat_rad, FALSE_EASTING_M, FALSE_NORTHING_M);

  // Perform Interpolation
  if(strncmp(method,cmpNN,strlen(cmpNN)) == 0) {
    if (interp_status = nn_interp(&output_grid,t,PROB_native,PROB_interp) != OK) {
      printf("Error interpolating grid\n");
    }
  } else if (strncmp(method,cmpNBAVG,strlen(cmpNBAVG)) == 0) {
    if (interp_status = nb_avg_interp(&output_grid,RP,t,PROB_native,PROB_interp) != OK) {
      printf("Error interpolating grid\n");
    }
  } else if (strncmp(method,cmpNBMAX,strlen(cmpNBMAX)) == 0) {
    if (interp_status = nb_max_interp(&output_grid,RP,t,PROB_native,PROB_interp) != OK) {
      printf("Error interpolating grid\n");
    }
  } else {
    printf("Unknown interpolation method\n");
  }

  // Calculate Lat/Lon arrays
  // Initialize interpolated state
  for(i=0; i<nlon; i++) {
    for(j=0; j<nlat; j++) {
      lon[j][i] = swlon + i*dlon;
      lat[j][i] = swlat + j*dlat;
    }
  }

  // Write output interpolated grid 
  // -----------------------------------------------------------------------------
  printf("Writing interpolated LamAz probability file: %s\n",outFileName);
  status[0]  = nc_create(outFileName,NC_CLASSIC_MODEL,&ncid);

  status[1]  = nc_def_dim(ncid,"y",nlat,&y_id);

  status[2]  = nc_def_dim(ncid,"x",nlon,&x_id);

  prob_dimids[0] = y_id;
  prob_dimids[1] = x_id;

  status[3]  = nc_def_var(ncid,outVarName,NC_FLOAT,2,prob_dimids,&prob_id);

  status[4]  = nc_put_att(ncid,prob_id,"_FillValue",NC_FLOAT,1,&mval);

  status[5]  = nc_def_var(ncid,"latitude",NC_FLOAT,2,prob_dimids,&lat_id);

  status[6]  = nc_def_var(ncid,"longitude",NC_FLOAT,2,prob_dimids,&lon_id);

  status[7]  = nc_put_att(ncid,NC_GLOBAL,"title",NC_CHAR,strlen(title),title);

  status[8]  = nc_put_att(ncid,NC_GLOBAL,"MapProjection",NC_CHAR,strlen(mapproj),mapproj);

  status[9]  = nc_put_att(ncid,NC_GLOBAL,"SWCornerLat",NC_DOUBLE,1,&swlat);

  status[10] = nc_put_att(ncid,NC_GLOBAL,"SWCornerLon",NC_DOUBLE,1,&swlon);

  status[11] = nc_put_att(ncid,NC_GLOBAL,"NECornerLat",NC_DOUBLE,1,&nelat);

  status[12] = nc_put_att(ncid,NC_GLOBAL,"NECornerLon",NC_DOUBLE,1,&nelon);

  status[13] = nc_put_att(ncid,NC_GLOBAL,"LatGridSpacing",NC_DOUBLE,1,&dlat);

  status[14] = nc_put_att(ncid,NC_GLOBAL,"LonGridSpacing",NC_DOUBLE,1,&dlon);

  status[15] = nc_put_att(ncid,NC_GLOBAL,"InitialTime",NC_CHAR,strlen(initialTime),initialTime);

  status[16] = nc_put_att(ncid,NC_GLOBAL,"ValidTime",NC_CHAR,strlen(validTime),validTime);

  status[17] = nc_put_att(ncid,NC_GLOBAL,"ForecastHr",NC_CHAR,strlen(forecastHr),forecastHr);

  status[18] = nc_enddef(ncid);  /*leave define mode*/

  status[19] = nc_put_varm_float(ncid,prob_id,start_out,count_out,stride_out,imap_out,*PROB_interp);

  status[20] = nc_put_varm_float(ncid,lat_id,start_out,count_out,stride_out,imap_out,*lat);

  status[21] = nc_put_varm_float(ncid,lon_id,start_out,count_out,stride_out,imap_out,*lon);

  status[22] = nc_close(ncid);

  for (i=0;i<23;i++) {
    if (status[i] != NC_NOERR) {
      printf("Error writing interpolated LamAz probability file\n");
      printf("status[%d] = ",i);
      handle_error(status[i]);
    }
  }

  // Deallocate dynamic arrays
  // Free 1D arrays
  free(*PROB_interp);
  free(*lat);
  free(*lon);
  
  // Free 2D arrays
  free(PROB_interp);
  free(lat);
  free(lon);

  // Exit normally
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
