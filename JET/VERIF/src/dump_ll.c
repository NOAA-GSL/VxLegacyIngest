/*******************************************************************************
This program computes the Lat/Lon values returned by the CIWS grid
 
By: Patrick Hofmann
Last Update: 11 APR 2011
*******************************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <cproj.h>

int main( int argc, char** argv ) 
{
  int numRows = 3520; 
  int numCols = 5120;
  double eastSpacing_m = 1000.;
  double northSpacing_m = 1000.;
  double centerLat_deg = 38.0;
  double centerLon_deg = -98.0;
  double falseEasting_m = 0.0;
  double falseNorthing_m = 0.0;
  double earthRadiusSpereical_m = 6370997.; /* see sphdz.c */
  
  double centerLat_rad = ( PI / 180. ) * centerLat_deg;
  double centerLon_rad = ( PI / 180. ) * centerLon_deg;
  int row, col;

  lamazinvint(earthRadiusSpereical_m, centerLon_rad, centerLat_rad, falseEasting_m, falseNorthing_m );

  for(row = -numRows/2 ; row < numRows/2 ; row++ ) {
    double y_m = (double)row * northSpacing_m;

    for(col = -numCols/2 ; col < numCols/2 ; col++ ) {
      double x_m = (double)col * eastSpacing_m; 
      double gc_lat_rad, gc_lon_rad;
      
      if( lamazinv( x_m, y_m, &gc_lon_rad, &gc_lat_rad ) != OK ) {
	fprintf( stderr, "Error converting x_m=%f, y_m=%f\n", x_m, y_m );
	exit( EXIT_FAILURE );
      } else {
	double gc_lat_deg = ( 180. / PI ) * gc_lat_rad; 
	double gc_lon_deg = ( 180. / PI ) * gc_lon_rad;

	printf(" %5d %5d : %7.1f %7.1f : %8.4f %8.4f\n", row, col, x_m*.001, y_m*.001, gc_lat_deg, gc_lon_deg );
      }
    }// for(col)
  } // for(row)
  exit( EXIT_SUCCESS );
}
