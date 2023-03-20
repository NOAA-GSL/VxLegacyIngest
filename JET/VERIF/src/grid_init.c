/*************************************************************************************************
grid_init.c

This function initializes structures for each scale of the NCWD grid.

By: Patrick Hofmann
Last Update: 08 JUNE 2011
*************************************************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <cproj.h>
#include <string.h>
#include <ncwdstruct.h>

int32_t grid_init(char* grid_str, GRID* output_grid)
{
  char cmpstr1[] = "ncwd_04km", cmpstr2[] = "ncwd_80km";
  
  if (strncmp(grid_str,cmpstr1,strlen(cmpstr1)) == 0) {
    char gridtype[] = "CylindricalEquidistant";
    strncpy(output_grid->mapproj,gridtype,strlen(gridtype));
    output_grid->nlat = 918;
    output_grid->nlon = 1830;
    output_grid->swlat = 20.01797;
    output_grid->swlon = -129.9809;
    output_grid->nelat = 52.968531;
    output_grid->nelon = -60.041769;
    output_grid->dlat =  0.035933;
    output_grid->dlon =  0.038239;
    output_grid->missing_value = -999;

    return(OK);

  } else if (strncmp(grid_str,cmpstr2,strlen(cmpstr2)) == 0) {
    char gridtype[] = "CylindricalEquidistant";
    strncpy(output_grid->mapproj,gridtype,strlen(gridtype));
    output_grid->nlat = 46;
    output_grid->nlon = 92;
    output_grid->swlat = 20.01797;
    output_grid->swlon = -129.9809;
    output_grid->nelat = 52.35767;
    output_grid->nelon = -60.38592;
    output_grid->dlat =  0.71866;
    output_grid->dlon =  0.76478;
    output_grid->missing_value = -999;

    return(OK);
  
  } else {
    printf("Unknown output grid specified\n");
    return(ERROR);
  }
}
