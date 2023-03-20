/* file candf.c */
/* converts between centegrade and farenheit. */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <ctype.h>

main ()
{
  float c = -99.;			/* centegrade  */
  float f = -99.;		/* farenheit */
  char line[80];
  
  printf(
   "Input centegrade temp <cr> for null): ");
  gets(line);
  sscanf(line,"%f",&c);
  printf(
   "Input farenheit temp <cr> for null): ");
  gets(line);
  sscanf(line,"%f",&f);

  /*see which way to convert */
  if(c == -99.) {
    c = (f-32.)*5./9.;
  } else {
    f = c*9./5. +32;
  }

  printf("\nc = %6.2f, f = %6.2f\n",c,f);
}
    

    
