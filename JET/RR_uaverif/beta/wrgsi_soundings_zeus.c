/* reads a RR grib file and generates sounding data
 * for MULTIPLE soundings
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <sys/types.h>
#include <unistd.h>
#include "gen_soundings.h"

main (int argc, char *argv[])
{
  FILE *input = NULL;
  int hydro = 0;
  int result;			/* stores return code for reads */
  raob_data_struct raob_data[MAX_LEVELS];
  float Z,Z1,T,T1,Q,Q1;
  float U,U1,V,V1;
  float P,P1;
  float CAPE,CIn,Helic,PW;
  float CLWMR,lnCLWMR,CLWMR1,lnCLWMR1;		/* cloud water mixing ratio */
  float RWMR,lnRWMR,RWMR1,lnRWMR1;		/* cloud water mixing ratio */
  float SNMR,lnSNMR,SNMR1,lnSNMR1;		/* cloud water mixing ratio */
  float ICMR,lnICMR,ICMR1,lnICMR1;		/* cloud water mixing ratio */
  float GRMR,lnGRMR,GRMR1,lnGRMR1;		/* cloud water mixing ratio */
  float t_kelvin,td_kelvin;
  char *filename;
  char month_name[4];
  int i,j,tot_len,bytes_per_item,startx,starty;
  int field_index;
  int j_mand;			/* counts mandatory levels */
  long mand_ht,mand_tp,mand_dp,mand_ws,mand_wd;
  long mand_clwmr,mand_rwmr,mand_snmr,mand_icmr,mand_grmr;
  int icount;			/* counts output levels */
  int done;
  long last_pressure;
  long pr,ws,wd,pr_next,t10_next,td10_next,ws_next,wd_next;
  long t10,td10;
  float fact;
  float xcart,ycart;
  float delta_east,delta_north;
  double radians;
  double valTimeD;		/* valid time */
  long valTime;
  float alat,elon,alat1,elon1,dx,elonv,alattan;
  char line[400];
  /* pressure now in tenths of mbs */
  long mand_level[] = {10000,9250,8500,7000,5000,4000,3000,2500,1500,1000};
  int mand_levels = 10;
  float grid_lat,grid_lon;
  float rotcon = 0;
  float dlon;
  float deg_to_radians = 0.0174533;
  float theta;			/* degrees to rotate winds from RUC coords */
  char *ptr;			/* pointer to parts of the input filename */
  int year,month,mday,jday,hour,fcst_proj;
  time_t valid_secs;
  struct tm tm;
  struct tm *tp;
  time_t startClock;
  time_t endClock;
  float endSecs;
  long int ticks_per_sec;
  char *model;
  char *station_file;
  int nx;
  int ny;
  int nz;
  /* PRES,HGT,TMP,SPFH,UGRD,VGRD,CLWMR,RWMR,SNMR ,CICE (= ICMR),GRMR*/
  int g3_fields[] = {1,7,11,51,33,34,153,170,171,58,179};
  int n_g3_fields = 11;
  int g2_fields[] = {157,156};
  int n_g2_fields = 2;
  char *out_filename;
  int floats_read=0;
  int floats_to_read=0;
  
  float *g3; 
  float *g2;
  int no_column = -1;
  int istatus=0;

  int arg_i = 1;
  AIRPORT *AIRPORTS[MAXTAILS];	/* holds airports */
  int n_airports=0;		/* holds the number of above */
  int max_airports = MAXTAILS;	/* holds max size of AIRPORT */
  int max_airport_id=0;
  int i_apt;
  AIRPORT *ap;
  int grib_type = 1;
 
  /* prototypes */
  void dewpoint2(float p, float t, float q, float *ptd);
  void w3fb11(float alat,float elon,
	    float alat1,float elon1,float dx,float elonv,float alatan,
	    float *pxi,float *pxj);
  void w3fb12(float xi,float xj,float alat1,float elon1,
	    float dx,float elonv,float alatan,
	    float *alat,float *elon);
  long my_interp(float fact,long x0,long x1);
  long my_dir_interp(float fact,long x0, long x1);
  time_t makeSecs(int year, int julday, int hour);
  int agrib_(int *nz_ptr, int *n_g3_fields,int *g3_fields,
	     int *n_g2_fields,int *g2_fields,
	     float *G3, float *G2,int *i_column,int *j_column,
	     char *filename, int *istatus_ptr );
  int read_airports(AIRPORT *p[],int max, char *filename,
		    int* max_id);

  if(argc < 12) {
    printf("Usage: agrib_soundings.x model filename grib_type tmp_file station_file"
	   "alat1 elon1 elonv alattan dx nx ny nz\n");
    exit(1);
  }
  model = argv[arg_i++];
  filename = argv[arg_i++];
  (void)sscanf(argv[arg_i++],"%d",&grib_type);
  out_filename = argv[arg_i++];
  station_file = argv[arg_i++];
  (void)sscanf(argv[arg_i++],"%f",&alat1);
  (void)sscanf(argv[arg_i++],"%f",&elon1);
  (void)sscanf(argv[arg_i++],"%f",&elonv);
  (void)sscanf(argv[arg_i++],"%f",&alattan);
  (void)sscanf(argv[arg_i++],"%f",&dx);
  (void)sscanf(argv[arg_i++],"%i",&nx);
  (void)sscanf(argv[arg_i++],"%i",&ny);
  (void)sscanf(argv[arg_i++],"%i",&nz);
  (void)sscanf(argv[arg_i++],"%i",&hydro);

  /* put dx in meters */
  dx *= 1000;
  printf("nz is %d\n",nz);

  g3 = (float *)malloc(sizeof(float)*n_g3_fields*nx*ny*nz);
  if(g3 == NULL) {
    printf("not enough space for g3 %d %d %d %d\n",
	   n_g3_fields,nx,ny,nz);
    exit(1);
  }
  g2 = (float *)malloc(sizeof(float)*n_g2_fields*nx*ny);
  if(g2 == NULL) {
    printf("not enough space for g2\n");
    exit(1);
  }

  /* get valid time from filename */
  /* e.g. "/path.../0336314000003.grib" */
  ptr = strrchr(filename,'/');
  sscanf(ptr,"/%2d%3d%2d0000%2d",&year,&jday,&hour,&fcst_proj);
  /* get day month and year */
  year += 2000;
  valid_secs = makeSecs(year,jday,hour) + 3600*fcst_proj;
   /* get tp to point to the tm structure */
  tp=&tm;
  tp = localtime(&valid_secs);
  year= tp->tm_year+1900;
  month = tp->tm_mon+1;
  mday = tp->tm_mday;
  hour = tp->tm_hour;
  (void)strftime(month_name,4,"%b",tp);

  /* list of airports */
  printf("max_airport_id = %d\n",max_airport_id);
  n_airports = read_airports(AIRPORTS,max_airports,station_file,
			     &max_airport_id);
  printf("Total airports loaded = %d from file %s\n"
	 "(includes airport zero, not in the file)\n",
	 n_airports,station_file);

  ticks_per_sec = sysconf(_SC_CLK_TCK);
  startClock = times(NULL);
  printf("reading grib file %s\n",filename);
  if(grib_type == 1) {
    result = agrib_(&nz,&n_g3_fields,g3_fields,
		    &n_g2_fields,g2_fields,
		    g3,g2,
		    &no_column,&no_column,
		    filename,&istatus);
    if(istatus != 0) {
      printf("trouble with agrib: all fields NOT filled.\n");
      return(-1);
    }
  } else {
    /* grib2 */
    snprintf(line,500,"./make_grib2_tmp_file.pl %s %s %d",
	     filename,out_filename,hydro);
    printf("command is %s\n",line);
    system(line);
    printf("finished dumping grib file\n");
    /* now read the dump file. */
    if ((input = fopen(out_filename,"r")) == NULL) {
      fprintf(stderr,"could not open file: %s\n", out_filename);
      exit(7);
    }
    floats_to_read = n_g3_fields*nx*ny*nz + n_g2_fields*nx*ny;
    floats_read = fread(g3,sizeof(float),n_g3_fields*nx*ny*nz,input);
    floats_read += fread(g2,sizeof(float),n_g2_fields*nx*ny,input);
    if(floats_read == floats_to_read) {
      printf("SUCCESS\n");
    } else {
      printf("%d floats read. Should have read %d\n",
	     floats_read,floats_to_read);
      exit(8);
    }
  }
    
  endClock = times(NULL);
  endClock -= startClock;
  endSecs = ((float)endClock)/ticks_per_sec;  
  printf("%.3f sec to read grib file\n",endSecs);

  /* loop over airports */
  for(i_apt=1;i_apt<n_airports;i_apt++) {
    ap = AIRPORTS[i_apt];
    alat = ap->lat;
    elon = ap->lon;
    printf("lat = %f, lon = %f, spacing (from file) = %f\n",alat,elon,dx);
    printf("station info: %s (%d) at %.0f meters elevation\n",
	   ap->name,ap->id,ap->elev);
    printf("alat1 %f elon1 %f elonv %f alattan %f dx %f\n",
	 alat1,elon1,elonv,alattan,dx);
  
  /* get the appropriate i,j */
  w3fb11(alat,elon,alat1,elon1,dx,elonv,alattan,&xcart,&ycart);
  printf("xcart,ycart = %f %f\n",xcart,ycart);
  /* get x,y point */
  startx = (int)(xcart+0.5);
  starty = (int)(ycart+0.5);
  if(startx < 0 || startx >= nx ||
     starty < 0 || starty >= ny) {
    printf("out of domain \n");
    continue;
  }
  w3fb12((float)startx,(float)starty,alat1,elon1,dx,elonv,alattan,
	 &grid_lat,&grid_lon);
  printf("grid lat lon = %.3f %.3f\n",grid_lat,grid_lon);
  delta_north = (grid_lat - alat)*59.9; /* nautical miles */
  delta_east = (grid_lon - elon)*cos(alat * 0.0175)*59.9; /* nm  */
  printf("delta_east= %f delta_north= %f\n",
	 delta_east,delta_north);

  j_mand=0;
  last_pressure = 99999;
  icount = 0;			/* counts output levels */
   for(i=0;i<nz;i++) {
     field_index = 0;
     P =   g3[startx + nx*(starty + ny*(i + nz*field_index++))];
     Z =   g3[startx + nx*(starty + ny*(i + nz*field_index++))];
     T =   g3[startx + nx*(starty + ny*(i + nz*field_index++))];
     Q =   g3[startx + nx*(starty + ny*(i + nz*field_index++))];
     U =   g3[startx + nx*(starty + ny*(i + nz*field_index++))];
     V =   g3[startx + nx*(starty + ny*(i + nz*field_index++))];
     lnCLWMR = MISSING;
     lnRWMR = MISSING;
     lnSNMR = MISSING;
     lnICMR = MISSING;
     lnGRMR = MISSING;
     CLWMR = g3[startx + nx*(starty + ny*(i + nz*field_index++))];
     if(CLWMR > 0) {
       lnCLWMR = log(CLWMR)*10;
     }
     RWMR = g3[startx + nx*(starty + ny*(i + nz*field_index++))];
     if(RWMR > 0) {
       lnRWMR = log(RWMR)*10;
     }
     SNMR = g3[startx + nx*(starty + ny*(i + nz*field_index++))];
     if(SNMR > 0) {
       lnSNMR = log(SNMR)*10;
     }
     ICMR = g3[startx + nx*(starty + ny*(i + nz*field_index++))];
     if(ICMR > 0) {
       lnICMR = log(ICMR)*10;
     }
     GRMR = g3[startx + nx*(starty + ny*(i + nz*field_index++))];
     if(GRMR > 0) {
       lnGRMR = log(GRMR)*10;
     }
     
     pr=P/10 + 0.5;		/* convert to millibars times 10 */
     dewpoint2(P,T,Q,&td_kelvin);
     t_kelvin = T;
     if(T < 50) {
       /* check for T == 0 and send mail if so tell someone*/
       FILE *mailpipe = popen("/usr/sbin/sendmail -t","w");
       if(mailpipe != NULL) {
	fprintf(mailpipe, "To: verif-amb.gsd@noaa.gov\n");
        fprintf(mailpipe, "From: amb-verif.processing.on,jet@noaa.gov\n");
        fprintf(mailpipe, "Subject: BAD TEMPERATURE in wrtsi_soundings.c\n\n");
        fprintf(mailpipe,"T < 50 for file %s\n",filename);
	fprintf(mailpipe, "lev %d, press: %.6g, Z: %.6g, T: %.2f, Q: %.2g, U: %.2g, V: %.2g\n",
		i+1,P,Z,T,Q,U,V);
        fwrite(".\n", 1, 2, mailpipe);
        pclose(mailpipe);
	exit(1);
       }
     }
     if(pr < last_pressure) {
       last_pressure = pr;
       t10 = (t_kelvin-273.15)*10 + 0.5;
       if(td_kelvin > MISSING -1) {
	 td10 = MISSING;
       } else {
	 td10 = (td_kelvin-273.15)*10 + 0.5;
       }
       /* get wind in kts, and direction */
       ws=(float)sqrt((double)(U*U + V*V)) / 0.51479 + 0.5 ;
       radians=atan2(U,V);
       /* rotate direction appropriately for the RUC grid */
       /* this means that S winds near the E coast need to pick up
	  an W component wrt true N.  So rotate the wind vectors
	  clockwise (+) near the E coast.
       */
       rotcon = sin(alattan*deg_to_radians);
       dlon = elonv - elon;
       while(dlon > 180) {dlon -= 360;}
       while (dlon < -180) {dlon += 360;}
       theta = - rotcon*(dlon);
       wd=(long)(radians*57.2958 + theta + 180. + 0.5);
       if(wd > 360) wd -= 360;
       if(wd < 0) wd += 360;

       if(i == 0) {
	 /* initial level: assume this is the surface */
	 raob_data[icount].fr = 9; /*surface*/
       } else {
	 raob_data[icount].fr = 5; /* sig level */
       }
       raob_data[icount].pr = pr;
       raob_data[icount].ht = Z + 0.5;  
       raob_data[icount].tp = t10;
       raob_data[icount].dp = td10;
       raob_data[icount].wd = wd;
       raob_data[icount].ws = ws;
       raob_data[icount].clwmr = lnCLWMR;
       raob_data[icount].rwmr = lnRWMR;
       raob_data[icount].snmr = lnSNMR;
       raob_data[icount].icmr = lnICMR;
       raob_data[icount].grmr = lnGRMR;
       icount++;

       /* for initial level, find out
	  how many mand levels are below the 'surface' */
       if(i == 0) {
	 done=0;
	 while (done == 0) {
	   if(mand_level[j_mand] > pr) {
	     /* we have crossed a mandatory level */
	     raob_data[icount].fr=4;
	     raob_data[icount].pr=mand_level[j_mand];
	     raob_data[icount].ht=MISSING;
	     raob_data[icount].tp = MISSING;
	     raob_data[icount].dp = MISSING;
	     raob_data[icount].wd = MISSING;
	     raob_data[icount].ws = MISSING;
	     raob_data[icount].clwmr = MISSING;
	     raob_data[icount].rwmr = MISSING;
	     raob_data[icount].snmr = MISSING;
	     raob_data[icount].icmr = MISSING;
	     raob_data[icount].grmr = MISSING;
	    
	     icount++;
	     j_mand++;
	     if(j_mand > mand_levels -1) {
	       done=1;
	     }
	   } else {
	     done=1;
	   }
	 }
       }
       /* check to see if the next level crosses any mand level */
       if(i < nz-1) {
	 field_index = 0;
	 P1 =   g3[startx + nx*(starty + ny*(i+1 + nz*field_index++))];
	 Z1 =   g3[startx + nx*(starty + ny*(i+1 + nz*field_index++))];
	 T1 =   g3[startx + nx*(starty + ny*(i+1 + nz*field_index++))];
	 Q1 =   g3[startx + nx*(starty + ny*(i+1 + nz*field_index++))];
	 U1 =   g3[startx + nx*(starty + ny*(i+1 + nz*field_index++))];
	 V1 =   g3[startx + nx*(starty + ny*(i+1 + nz*field_index++))];
	 CLWMR1 = g3[startx + nx*(starty + ny*(i+1 + nz*field_index++))];
	 lnCLWMR1 = MISSING;
	 if(CLWMR1 > 0) {
	   lnCLWMR1 = log(CLWMR1)*10;
	 }
	 RWMR1 = g3[startx + nx*(starty + ny*(i+1 + nz*field_index++))];
	 lnRWMR1 = MISSING;
	 if(RWMR1 > 0) {
	   lnRWMR1 = log(RWMR1)*10;
	 }
	 SNMR1 = g3[startx + nx*(starty + ny*(i+1 + nz*field_index++))];
	 lnSNMR1 = MISSING;
	 if(SNMR1 > 0) {
	   lnSNMR1 = log(SNMR1)*10;
	 }
	 ICMR1 = g3[startx + nx*(starty + ny*(i+1 + nz*field_index++))];
	 if(ICMR1 > 0) {
	   lnICMR1 = log(ICMR1)*10;
	 }
	 GRMR1 = g3[startx + nx*(starty + ny*(i+1 + nz*field_index++))];
	 if(GRMR1 > 0) {
	   lnGRMR1 = log(GRMR1)*10;
	 }

	 pr_next = P1/10 + 0.5;
	 dewpoint2(P1,T1,Q1,&td_kelvin);
	 t_kelvin = T1;
	 t10_next = (t_kelvin-273.15)*10 + 0.5;
	 if(td_kelvin > MISSING - 1) {
	   td10_next = MISSING;
	 } else {
	   td10_next = (td_kelvin-273.15)*10 + 0.5;
	 }
	 /* get wind in kts, and direction */
	 ws_next=(float)sqrt(
		  (double)(U1*U1 + V1*V1)) / 0.51479 + 0.5 ;
	 radians=atan2(U1,V1);
	 /* rotate direction appropriately for the RUC grid */
	 /* this means that S winds near the E coast need to pick up
	    an W component wrt true N.  So rotate the wind vectors
	    clockwise (+) near the E coast.
	 */
	 rotcon = sin(alattan*deg_to_radians);
	 dlon = elonv - elon;
	 while(dlon > 180) {dlon -= 360;}
	 while (dlon < -180) {dlon += 360;}
	 theta = - rotcon*(dlon);
	 wd_next=(long)(radians*57.2958 + theta + 180. + 0.5);
	 if(wd_next > 360) wd_next -= 360;
	 if(wd_next < 0) wd_next += 360;
	 done=0;
	 while (done == 0 && j_mand < mand_levels) {
	   /* make sure the next level is at a lower pressure */
	   if(pr_next < pr && pr_next < mand_level[j_mand]) {
	     /* interpolate in log p */
	     fact=((float)(log((double)pr)-log((double)mand_level[j_mand]))) /
	       (log((double)pr)-log((double)pr_next));
	     mand_ht=my_interp(fact,Z,Z1);
	     mand_tp=my_interp(fact,t10,t10_next);
	     mand_dp=my_interp(fact,td10,td10_next);
	     mand_ws=my_interp(fact,ws,ws_next);
	     mand_wd=my_dir_interp(fact,wd,wd_next);
	     mand_clwmr = my_interp(fact,lnCLWMR,lnCLWMR1);
	     mand_rwmr = my_interp(fact,lnRWMR,lnRWMR1);
	     mand_snmr = my_interp(fact,lnSNMR,lnSNMR1);
	     mand_icmr = my_interp(fact,lnICMR,lnICMR1);
	     mand_grmr = my_interp(fact,lnGRMR,lnGRMR1);
	     raob_data[icount].fr = 4; /* mandatory level */
	     raob_data[icount].pr = mand_level[j_mand];
	     raob_data[icount].ht = mand_ht;
	     raob_data[icount].tp = mand_tp;
	     raob_data[icount].dp = mand_dp;
	     raob_data[icount].wd = mand_wd;
	     raob_data[icount].ws = mand_ws;
	     raob_data[icount].clwmr = mand_clwmr;
	     raob_data[icount].rwmr = mand_rwmr;
	     raob_data[icount].snmr = mand_snmr;
	     raob_data[icount].icmr = mand_icmr;
	     raob_data[icount].grmr = mand_grmr;
	     if( mand_level[j_mand] == 1500) {
	       printf("mand 150mb: this.next, pr: %.2f/%.2f, t, T %.2f/%.2f (%.2f), fact: %.2f\n",
		      pr,pr_next,t10,t10_next,mand_tp,fact);
	     }
	     icount++;
	     j_mand++;
	     if(j_mand > mand_levels-1) {
	       done=1;
	     }
	   } else {
	     done=1;
	   }
	 } /* end while not done */
       }
     } /* end pressure different section */
   } /* end loop over heights */

  /* stability information */
  field_index = 0;
  CAPE = g2[startx + nx*(starty + ny*field_index++)];
  CIn =  g2[startx + nx*(starty + ny*field_index++)];
  /* no Helic or PW in these files */
  Helic = 99999;
  PW = 99999;

  /* see what it looks like */
  printf("Begin sounding data for %s:\n",ap->name);
  printf("   CAPE%7.0f    CIN%7.0f  Helic%7.0f     PW%7.0f\n",
	 CAPE,CIn,Helic,PW);
  
  i=1;
  j=23062;
  
  printf("%7d%7d%7d%7.2f%7.2f%7.0f%7d\n",i,j,ap->wmo_id,
	 grid_lat,-grid_lon,ap->elev,MISSING);
  printf("%7d%7d%7d%7d%7d%7d%7d\n",
	 2,MISSING,MISSING,MISSING,icount+4,MISSING,MISSING);
  printf("      3           %-19.19s   12     kt\n",
	 ap->name);
   for(i=0;i<icount;i++) {
     printf("%7ld%7ld%7ld%7ld%7ld%7ld%7ld\n",
	    raob_data[i].fr,
	    raob_data[i].pr,
	    raob_data[i].ht,
	    raob_data[i].tp,
	    raob_data[i].dp,
	    raob_data[i].wd,
	    raob_data[i].ws);
   }
   printf("End sounding data\n");
   printf("Begin hydrometeor data for %s:\n",ap->name);
   for(i=0;i<icount;i++) {
     if(hydro==1 &&
	(raob_data[i].clwmr != MISSING || raob_data[i].rwmr != MISSING ||
	 raob_data[i].snmr != MISSING || raob_data[i].icmr != MISSING ||
	 raob_data[i].grmr != MISSING)) {
       printf("%7ld%7ld%7ld%7ld%7ld%7ld\n",
	      raob_data[i].pr,
	      raob_data[i].clwmr,
	      raob_data[i].rwmr,
	      raob_data[i].snmr,
	      raob_data[i].icmr,
	      raob_data[i].grmr
	      );
       /*xue 20140521
       if(raob_data[i].grmr != MISSING) {
	 fprintf(stderr,"igroupel for %s: %ld, %ld\n",
		 ap->name,raob_data[i].icmr ,raob_data[i].grmr);
		 }*/
     }
   }
   printf("End hydrometeor data\n");
  }
  return 1;			/* keep lint happy (main defined to return int */
}
/**********************************************************************/

void dewpoint2(float p, float tk, float q, float *ptd) {
  /* ;;returns dewpoint in kelvin,
     ;; given pressure in pascals, t in kelvin
     ;; and specific humidity (q)
     ;; ptd is pointer to (output) dewpoint
     */

  double esw_pascals,e_pascals,log10_e,dewpoint;
  double exnr,cpd_p,rovcp_p,pol,rh,qv;
  double tx,e,exner;

  cpd_p=1004.686;
  rovcp_p=0.285714;		/* R/cp */
  exner = cpd_p*pow((p/100000.),rovcp_p);
  qv = q/(1.-q);
  
  /* Stan's way of calculating sat vap pressure: 
  tx = tk-273.15;
  pol = 0.99999683       + tx*(-0.90826951e-02 +
      tx*(0.78736169e-04   + tx*(-0.61117958e-06 +
      tx*(0.43884187e-08   + tx*(-0.29883885e-10 +
      tx*(0.21874425e-12   + tx*(-0.17892321e-14 +
      tx*(0.11112018e-16   + tx*(-0.30994571e-19)))))))));
  esw_old_pascals = 6.1078/pow(pol,8.) *100.; 
  */
  
  /* Rex's way of calculating sat vap pressure: */
  /* From Fan and Whiting (1987) as quoted in Fleming (1996): BAMS 77, p
     2229-2242, the saturation vapor pressure is given by: */
  esw_pascals=pow(10.,((10.286*tk - 2148.909)/(tk-35.85)));
  e = p*qv/(0.62197+qv);
  rh = e/esw_pascals;
  if(rh == 0) {
    dewpoint = MISSING;
  } else {
  
    /*printf("Temp: %f, rh %f Saturation: old,new= %f %f\n",
      tx,rh,esx,esw_pascals);*/
    
    e_pascals = rh*esw_pascals;
    log10_e = log10(e_pascals);
    
    /* invert the formula for esw to see the temperature at which
       e is the saturation value */
    
    dewpoint = ((-2148.909 + 35.85*log10_e)/(-10.286 + log10_e));
  }
  *ptd = (float)dewpoint;
}

long my_interp(float fact,long x0,long x1) {
  long iresult;
  long round(float arg);
  if(x0 == MISSING || x1 == MISSING) {
    iresult=MISSING;
  } else {
    iresult=round(x0 + fact*(x1 - x0));
  }
  return (iresult);
}

long my_dir_interp(float fact,long x0, long x1) {
  /* interpolates wind directions in the range 0 - 359 degrees */
  long result;
  long dir_dif;
  long round(float arg);
  if(x0 == MISSING || x1 == MISSING) {
    result=MISSING;
  } else {
    dir_dif = x1 - x0;
    if(dir_dif > 180) {
      dir_dif -= 360;
    } else if(dir_dif < -180) {
      dir_dif += 360;
    }
    result = round(x0 + fact*(dir_dif));
    if(result < 0) {
      result += 360;
    } else if(result > 359) {
      result -= 360;
    }
  }
  return (result);
}

long round(float arg) {
  long i_arg;
  float dif;

  i_arg = arg;
  dif = arg - i_arg;

  if(dif > 0.5) {
    i_arg++;
  } else if(dif < -0.5) {
    i_arg--;
  }

  return i_arg;
}
  
time_t makeSecs(int year, int julday, int hour) {
/* makes number of secs since 1970 from an atime.  see p 111 of
 kernighan and Richie, 2nd ed.
 */
  struct tm tm;
  struct tm *tp;
  static int daytab[2][13] = {
    {0,31,28,31,30,31,30,31,31,30,31,30,31},
    {0,31,29,31,30,31,30,31,31,30,31,30,31}
  };
  time_t timet;
  int i,leap;

  /* get tp to point to the tm structure */
  tp=&tm;
  
  tp->tm_sec=0;
  tp->tm_min=0;
  tp->tm_hour=hour;
  tp->tm_year = year-1900;

  /* get month and day from julian day */
  leap = (year%4 == 0 && year%100 != 0) || year%400 == 0;
  for(i=1;julday>daytab[leap][i];i++)
    julday -= daytab[leap][i];

  tp->tm_mon = i-1;             /* months should start at zero */
  tp->tm_isdst = -1;            /* flag to calculate dst */
  tp->tm_mday = julday;         /* it is now just the left-over days */
  timet = mktime(tp);
  return timet;
}
  
