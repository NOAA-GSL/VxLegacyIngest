/***************************************************************************************************
allocate.c

This file contains general routines for dynamically allocating 1D, 2D, and 3D arrays.
Also, there is a routine to free the dynamic memory for a 2D array.

Original routines written by Curtis Alexander.

By: Patrick Hofmann
Last Update: 13 JUN 2011
***************************************************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <cproj.h>
#include <sys/types.h>

/******************************************************************************************
Function: alloc_1d
Input:		
Output:		
*******************************************************************************************/
int32_t alloc_1d(int32_t nummemb, size_t size, void** array)
{
  void* arrayptr = NULL;

  /* Allocate row */
  arrayptr = (void*) calloc(nummemb, size);
  if(arrayptr == NULL)
  { 
    fprintf(stderr, "Error: Unable to allocate %ld bytes of memory.\n", nummemb*size);
    return(ERROR);
  }

  *array = arrayptr;
  return(OK);
}


/******************************************************************************************
Function: alloc_2d
Input:		
Output:		
*******************************************************************************************/
int32_t alloc_2d(int32_t numxmemb, int32_t numymemb, size_t size, void*** array)
{
  void** arrayptr = NULL;
  int32_t xmemb = 0;

  /* Allocate pointers to rows */
  if(alloc_1d(numxmemb, sizeof(void*), (void**) &arrayptr) == ERROR)
    return(ERROR);

  /* Allocate rows */
  if(alloc_1d(numxmemb*numymemb, size, (void**) arrayptr) == ERROR)
    return(ERROR);
  
  /* Set pointers to rows */
  for(xmemb = 1; xmemb < numxmemb; xmemb++)
    arrayptr[xmemb] = arrayptr[xmemb - 1] + numymemb*size;
  
  *array = arrayptr;
  return(OK);
}


/******************************************************************************************
Function: alloc_3d
Input:		
Output:		
*******************************************************************************************/
int32_t alloc_3d(int32_t numxmemb, int32_t numymemb, int32_t numzmemb, size_t size, void**** array)
{
  void*** arrayptr = NULL;
  int32_t xmemb = 0;
  int32_t ymemb = 0;
  
  /* Allocate pointers to pointers to rows */
  if(alloc_1d(numxmemb, sizeof(void**), (void**) &arrayptr) == ERROR)
    return(ERROR);

  /* Allocate pointers to rows */
  for(xmemb = 0; xmemb < numxmemb; xmemb++)
  {
    if(alloc_1d(numxmemb*numymemb, sizeof(void*), (void**) &(arrayptr[xmemb])) == ERROR)
      return(ERROR);
  }
  
  /* Allocate rows */
  if(alloc_1d(numxmemb*numymemb*numzmemb, size, (void**) *arrayptr) == ERROR)
    return(ERROR);

  /* Set pointers to rows */
  for(xmemb = 0; xmemb < numxmemb; xmemb++)
  {
    for(ymemb = 0; ymemb < numymemb; ymemb++)
    {
      arrayptr[xmemb][ymemb] = **arrayptr + xmemb*(numymemb)*(numzmemb)*(size) + ymemb*(numzmemb)*(size);
    }
  }
  
  *array = arrayptr;

  return(OK);
}

/******************************************************************************************
Function: free_2d
Input:		
Output:		
*******************************************************************************************/
int32_t free_2d(int32_t numxmemb, void*** array)
{
  int32_t x;
  
  /* Free array block */
  free(*array);

  /* Free array field pointers to 1-D arrays */
  //for(x = 0; x < numxmemb; x++)
  //{
  //  free(array[x]);
  //}

  /* Free array field pointers to 2-D arrays */
  free(array);

  return(OK);
}
