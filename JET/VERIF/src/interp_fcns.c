/*************************************************************************************************
interp_fcns.c

These functions interpolates WAF, CIWS, and MITLL Probability fields from their native grid - 
Lambert Azimuthal Equal Area to the NCWD domained Cylindrical Equidistant (Lat/Lon) grid.
Interpolation routines exist for Neighbor-Budget Linear Average, Neighbor-Budget Max Value, and
Nearest Neighbor.  

By: Patrick Hofmann
Last Update: 02 MAY 2011
*************************************************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <cproj.h>
#include <wafgrid.h>
#include <ncwdstruct.h>

/* Neighbor-Budget Linear Average Interpolation Routine
-------------------------------------------------------
Modeled after the FORTRAN library: IPOLATES.  The algorithm computes (weighted) averages of
neighbor points arranged in a square box centered around each output grid point and stretching
nearly halfway to each of the neighboring grid points.  The NASA library GCTPC is used for
X/Y <-> Lat/Lon transformations. 

Options: RP: number of points in each radius from the center point (default=2)
         WB: weights for the radius points, starting at center point (default=1)
*/
int nb_avg_interp(GRID *output_grid, int32_t RP, int32_t t, float native_state[NT][NY][NX], float **interp_state)
{
  // Interpolation options
  // (2*RP + 1)^2 is the number of points that will be searched for a max value
  int WB[25] = {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1};
  
  int weights[output_grid->nlat][output_grid->nlon], counts[output_grid->nlat][output_grid->nlon], missing_counts[output_grid->nlat][output_grid->nlon];
  int i,j, k, len, igrid, jgrid;
  double np, i_offset, j_offset, lon, lat, x_m, y_m;
  float mval = output_grid->missing_value;
  
  printf("Performing Neighbor-Budget Linear Average Interpolation...\n");

  // Initialize interpolated state
  for(i=0; i<output_grid->nlon; i++) {
    for(j=0; j<output_grid->nlat; j++) {
      interp_state[j][i] = 0;
      counts[j][i] = 0;
      missing_counts[j][i] = 0;
    }
  }
  
  // Calculate box length and number of neighboring interpolated points for nearest neighbor
  len = 2*RP+1;
  np = SQUARE(len);
  
  for(k=0; k<np; k++) {
    // Calculate (i,j) offsets on Lat/Lon grid based upon neighbor-budget
    i_offset = .99*(k/len - RP)/(double)(len-1);
    j_offset = .99*(k%len - RP)/(double)(len-1);
    //printf("k = %d: i_off = %f j_off = %f\n",k,i_offset,j_offset);
    
    // Loop over output grid Lat/Lon values
    for(i = 0; i < output_grid->nlon; i++) {
      lon = (output_grid->swlon + i*output_grid->dlon + i_offset*output_grid->dlon) * (PI/180.);
      
      for(j = 0; j < output_grid->nlat; j++) {
	lat = (output_grid->swlat + j*output_grid->dlat + j_offset*output_grid->dlat) * (PI/180.);
	
	// Call forward integration from Lat/Lon to X/Y
	if( lamazfor( lon, lat, &x_m, &y_m ) != OK ) {
	  fprintf( stderr, "Error converting lon=%f, lat=%f\n", lon, lat);
	  return(-1);
	} else {
	  // Turn (x,y) location into nearest native gridpoint
	  igrid = CENTER_I + round(x_m/EAST_SPACING_M);
	  jgrid = CENTER_J + round(y_m/NORTH_SPACING_M);
	  //printf("%d %d \n", jgrid,igrid);
	  
	  // Ensure native grid bounds haven't been overstep
	  if (igrid >= NX || jgrid >= NY || igrid < 0  || jgrid < 0) {
	    missing_counts[j][i] += 1;
	  } else {
	    // Assign interpolated gridpoint to the nearest native gridpoint
	    if (native_state[t][jgrid][igrid] != mval) {
	      interp_state[j][i] += WB[k]*native_state[t][jgrid][igrid];
	      weights[j][i] += WB[k];
	      counts[j][i] += 1;
	    }
	  } // if(out of grid)
	} // if(lamazfor OK)
      } // for(lat)
    } // for(lon)
  } // for(k)
  
  // Weight all neighboring points together, must have at least 50% non-missing to assign value
  for(i = 0; i < output_grid->nlon; i++) {
    for(j = 0; j < output_grid->nlat; j++) {
      if (counts[j][i] >= 0.5*np && counts[j][i] > missing_counts[j][i]) {
	interp_state[j][i] /= weights[j][i];
      } else {
	interp_state[j][i] = mval;
      }
    }
  }
  return(OK);
} // nb_interp()

//*************************************************************************************************

/* Neighbor-Budget Max Value Interpolation Routine
-------------------------------------------------------
Modeled after the FORTRAN library: IPOLATES.  The algorithm computes the max value of
neighbor points arranged in a square box centered around each output grid point and stretching
nearly halfway to each of the neighboring grid points.  The NASA library GCTPC is used for
X/Y <-> Lat/Lon transformations. 

Options: RP: number of points in each radius from the center point (default=2)
*/
int nb_max_interp(GRID *output_grid, int32_t RP, int32_t t, float native_state[NT][NY][NX], float **interp_state) 
{
  // Interpolation options
  // (2*RP + 1)^2 is the number of points that will be searched for a max value
  
  int i,j, k, len, igrid, jgrid;
  double np, i_offset, j_offset, lon, lat, x_m, y_m;
  float mval = output_grid->missing_value;
  
  printf("Performing Neighbor-Budget Max Value Interpolation...\n");

  // Initialize interpolated state
  for(i=0; i<output_grid->nlon; i++) {
    for(j=0; j<output_grid->nlat; j++) {
      interp_state[j][i] = 0;
    }
  }
  
  // Calculate box length and number of neighboring interpolated points for nearest neighbor
  len = 2*RP+1;
  np = SQUARE(len);
  
  for(k=0; k<np; k++) {
    // Calculate (i,j) offsets on Lat/Lon grid based upon neighbor-budget
    i_offset = .99*(k/len - RP)/(double)(len-1);
    j_offset = .99*(k%len - RP)/(double)(len-1);
    //printf("k = %d: i_off = %f j_off = %f\n",k,i_offset,j_offset);
    
    // Loop over output grid Lat/Lon values
    for(i = 0; i < output_grid->nlon; i++) {
      lon = (output_grid->swlon + i*output_grid->dlon + i_offset*output_grid->dlon) * (PI/180.);
      
      for(j = 0; j < output_grid->nlat; j++) {
	lat = (output_grid->swlat + j*output_grid->dlat + j_offset*output_grid->dlat) * (PI/180.);
	
	// Call forward integration from Lat/Lon to X/Y
	if( lamazfor( lon, lat, &x_m, &y_m ) != OK ) {
	  fprintf( stderr, "Error converting lon=%f, lat=%f\n", lon, lat);
	  return(-1);
	} else {
	  // Turn (x,y) location into nearest native gridpoint
	  igrid = CENTER_I + round(x_m/EAST_SPACING_M);
	  jgrid = CENTER_J + round(y_m/NORTH_SPACING_M);
	  //printf("%d %d \n", jgrid,igrid);
	  
	  // Ensure native grid bounds haven't been overstep
	  if (igrid >= NX || jgrid >= NY || igrid < 0  || jgrid < 0) {
	    interp_state[j][i] = mval;
	  } else {
	    // Assign interpolated gridpoint to the nearest native gridpoint
	    if (native_state[t][jgrid][igrid] != mval) {
	      if (native_state[t][jgrid][igrid] >= interp_state[j][i]) {
		interp_state[j][i] = native_state[t][jgrid][igrid];
	      }
	    }
	  } // if(out of grid)
	} // if(lamazfor OK)
      } // for(lat)
    } // for(lon)
  } // for(k)
  
  return(OK);
} // nb_max_interp()

//*************************************************************************************************

// Nearest Neighbor Interpolation Routine
// -------------------------------------
int nn_interp(GRID *output_grid, int32_t t, float native_state[NT][NY][NX], float **interp_state)
{
  int i,j, k, len, igrid, jgrid;
  double lon, lat, x_m, y_m;
  float mval = output_grid->missing_value;
  
  printf("Performing Nearest Neighbor Interpolation...\n");
  
  // Initialize interpolated state
  for(i=0; i<output_grid->nlon; i++) {
    for(j=0; j<output_grid->nlat; j++) {
      interp_state[j][i] = 0;
    }
  }
  
  // Loop over output grid Lat/Lon values
  for(i = 0; i < output_grid->nlon; i++) {
    lon = (output_grid->swlon + i*output_grid->dlon) * (PI/180.);
    
    for(j = 0; j < output_grid->nlat; j++) {
      lat = (output_grid->swlat + j*output_grid->dlat) * (PI/180.);
      
      // Call forward integration from Lat/Lon to X/Y
      if( lamazfor( lon, lat, &x_m, &y_m ) != OK ) {
	fprintf( stderr, "Error converting lon=%f, lat=%f\n", lon, lat);
	return(-1);
      } else {
	// Turn (x,y) location into nearest native gridpoint
	igrid = CENTER_I + round(x_m/EAST_SPACING_M);
	jgrid = CENTER_J + round(y_m/NORTH_SPACING_M);
	//printf("%d %d \n", jgrid,igrid);
	
	// Ensure native grid bounds haven't been overstep
	if (igrid >= NX || jgrid >= NY || igrid < 0  || jgrid < 0) {
	  interp_state[j][i] = mval;
	} else {
	  // Assign interpolated gridpoint to the nearest native gridpoint
	  interp_state[j][i] = native_state[t][jgrid][igrid];
	} // if(out of grid)
      } // if(lamazfor OK)
    } // for(lat)
  } // for(lon)
  return(OK);
} // nn_interp()

//*************************************************************************************************


