/* reads a netCDF file and dumps all fields together for each rec number
 * arguments:
 * filename
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>

#include "netcdf.h"

#define BUFFER_SIZE 1000000
#define MAX_NO_FIELDS 100
#define MAX_NO_DIMS 5
#define N_PER_LINE 4

main (int argc, char *argv[])
{
  int bin_data;			/* file descriptor for output data */
  long start[]={0,0,0,0,0};
  char buffer[BUFFER_SIZE];
  char *filename;
  char fieldname[MAX_NO_FIELDS][MAX_NC_NAME];
  char *typestring[MAX_NO_FIELDS];
  nc_type fieldtype[MAX_NO_FIELDS];
  int bytes_per_item[MAX_NO_FIELDS];
  long bytes_per_record[MAX_NO_FIELDS];
  int items_per_record[MAX_NO_FIELDS];
  int field_n_dims[MAX_NO_FIELDS];
  char * data_ptr[MAX_NO_FIELDS];  /* pointer to start of field data */
  long data_index;		/* index within each field */
  long field_dim_values[MAX_NO_FIELDS][MAX_NO_DIMS];
  char input_file[80];
  long n_recs,data_dim_values[MAX_NO_DIMS];
  int nc_id,rec_id;
  int data_id,data_ndims,n_dims,n_gatts,unlim_id,n_vars,
      data_dimids[MAX_NO_DIMS];
  int i,j,k,m,tot_len;
  
  /* prototypes */
  void my_varget(int ncid,int n_recs,char *name,void *values);
  void my_stringget(int ncid,int n_recs,int n_chars,char *name,char *values);
  void printItem(int fieldtype, char *ptr) ;
  if(argc != 2) {
    fprintf(stderr,"!!%d usage: ncdump2.x <filename>\n",argc);
    exit(1);
  }

  filename = argv[1];
  (void) sprintf(input_file,"%s",filename);
    
  ncopts=NC_VERBOSE;			/* don't die on read errors */
  nc_id=ncopen(input_file,NC_NOWRITE);
  if(nc_id == -1) {
    fprintf(stderr,"!!No data found for %s\n",input_file);
    exit(2);
  }
  printf("- ncdump2 dumps netcdf files, and puts all variables for \n"
	 "  each record number together.\n\n"
	 "- Variables of type 'byte' and 'char' are printed as chars,\n"
	 "  with the exception that actual semicolons in char variables\n"
	 "  are printed as '<semicolor>', to distinguish them from\n"
	 "  actual semicolons that delimit variables,\n"
	 "  and actual newlines in char variables are printed\n"
	 "  as '<newline>', to distinguish them from actual\n"
	 "  newlines that separate data from different record numbers\n\n"
	 "- Values > 1.e10 are printed as 'inf'\n\n"
	 "- Doubles > 800000000 are printed (in addition) as dates\n\n"
	 "- Records are separated by newlines.\n\n"
	 "- Only variables that have the unlimited dimension as their\n"
	 "  first dimension are printed out.\n\n");

  /* now read the acars file. */
  ncinquire(nc_id,&n_dims,&n_vars,&n_gatts,&unlim_id);
  ncdiminq(nc_id,unlim_id,(char *) 0,&n_recs);

  /*printf("%s has %d fields, each with %d records\n",
	 filename,n_vars,n_recs); */

  if(n_vars > MAX_NO_FIELDS) {
    printf("MORE THAN %d fields.  Quitting...\n", MAX_NO_FIELDS);
    exit(0);
  }
  
  /* loop over fieldnames */
  for (j=0;j<n_vars;j++) {
    ncvarinq(nc_id,j,fieldname[j],&fieldtype[j],&field_n_dims[j],
	     data_dimids,(int *) 0);
    /* printf("Field %d (%s) is of type %d with %d dimensions\n",
	   j,fieldname[j],fieldtype[j],field_n_dims[j]); */

    /* store this field */
    /* get size of field */
    bytes_per_item[j]=1;
    switch(fieldtype[j]) {
    case NC_BYTE:
      typestring[j]="byte";
      break;
    case NC_CHAR:
      typestring[j]="char";
      break;
    case NC_SHORT:
      bytes_per_item[j]=2;
      typestring[j]="short";
      break;
    case NC_FLOAT:
      typestring[j]="float";
      bytes_per_item[j]=4;
      break;
     case NC_LONG: 
      typestring[j]="long";
      bytes_per_item[j]=4;
      break;
    case NC_DOUBLE:
      typestring[j]="double";
      bytes_per_item[j]=8;
      break;
    }

  if(field_n_dims[j] > MAX_NO_DIMS) {
    fprintf(stderr,"!!too many dimensions!\n");
    exit(2);
  }
  
 /* find the values of each dimension */
  tot_len=1;
  printf("Field %s (%s) has %d dimension(s): ",fieldname[j], typestring[j],
	 field_n_dims[j]);
  if(field_n_dims[j] == 0) {
    continue;
  }
  for (i=0;i<field_n_dims[j];i++) {
    ncdiminq(nc_id,data_dimids[i],(char *) 0,&field_dim_values[j][i]);
    printf("%d ", field_dim_values[j][i]); 
   /* get it in bytes */
   tot_len *= field_dim_values[j][i];
  }
   printf("\n");
  tot_len *= bytes_per_item[j];
  bytes_per_record[j] = tot_len/field_dim_values[j][0];
  items_per_record[j]=bytes_per_record[j]/bytes_per_item[j];

  /* make space for this field */
  /*printf("    Total size of this field is %d bytes\n",tot_len);*/
  data_ptr[j] = (char *)malloc(tot_len);
  if(data_ptr[j] == NULL) {
    fprintf(stderr,"!!No space available to store this field!!\n");
    exit(2);
  }

  /* store this field */
    ncvarget(nc_id,j,start,field_dim_values[j],(void *)data_ptr[j]);
  }

  /* it is all in now, so spit it out */
  printf("\nOrder of printout:\n\n#####RECORD No ;");
  for(j=0;j<n_vars;j++) {
    /* skip fields that don't use the unlimited dimension */
    if(field_dim_values[j][0] == n_recs) {
      if(j%N_PER_LINE == 0) {
	printf("\n");
      }
      printf("\t%s ;",fieldname[j]);
    }
  }
  printf("\n\nDATA:\n");
  for (i=0;i<n_recs;i++) {
    printf("#####RECORD %d;",i);
    for (j=0;j<n_vars;j++) {
    if(field_dim_values[j][0] == n_recs) {

      /* get pointer to first variable of this field */
      data_index = i*bytes_per_record[j];
      for(k=0;k<items_per_record[j];k++) {
	if(k == 0) {
	  if(j%N_PER_LINE == 0) {
	    printf ("\n\t(%s:) ",fieldname[j]);
	  } else {
	    printf("\t");
	  }
	}
	printItem(fieldtype[j],data_ptr[j]+data_index);
	data_index += bytes_per_item[j];
      }
      printf (";");
    }
    } /* end of loop over variables for this record */
    printf("\n");
  } /* end of loop over records */
}

void printItem(int fieldtype, char *ptr) {
  char time[20];
  int k;
  long lng;
  switch(fieldtype) {
	case NC_BYTE: case NC_CHAR:
	  if(*ptr == ';') {
	    printf("<semicolon>");
	  } else if (*ptr == '\n') {
	    printf("<newline>");
	  } else if (*ptr == '\0') {
	    printf("\\0");
	  } else {
	    printf("%c",*ptr);
	  }
	  break;
	case NC_SHORT:
	  printf("%hd",*((short *)ptr));
	  break;
	case NC_FLOAT:
	  if(*((float *)ptr) > 1.e10) {
	    printf("inf");
	  } else {
	    printf("%g",*((float *)ptr));
	  }
	  break;
	case NC_DOUBLE:
	  lng = *((double *)ptr);
	  printf("%ld",lng);
	  /* it might be a time, so print out the equivalent time */
	  if(lng > 800000000) {
	    strftime(time,19,"%d-%b-%y %H:%M:%S",gmtime(&lng));
	    printf("(%s)",time);
	  }
	  break;
        case NC_LONG:
	  printf("%ld",*((long *)ptr));
  }
}

 
   
