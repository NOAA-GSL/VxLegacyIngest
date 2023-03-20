/* reads a RUC grib file and generates sounding data
 * for MULTIPLE soundings
 * 25-Nov-2005
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
  int hydro = 1;		/* 1 to generate hydrometeor data here */
  int result;			/* stores return code for reads */
  raob_data_struct raob_data[MAX_LEVELS];
  float Z,Z1,T,T1,RH,RH1;
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
  float alat,elon;
  int grid_type;
  float dx;
  int nx,ny,nz;

  /* HARDWIRE FOR RR rotLL grid */
  /*float lat_0_deg = 47.5;
    float lon_0_deg = -104.;
  float lat_g_SW_deg = 2.227524;
  float lon_g_SW_deg = -140.4815;
  float dx = 13.54508;
  int nx = 758;
  int ny = 567;
  int nz = 50;
  */


  /* for RAP rotLL grid */
  float lat_0_deg;
  float lon_0_deg;
  float lat_g_SW_deg;
  float lon_g_SW_deg;
  float dxLL;
  int nxLL;
  int nyLL;
  int nzLL ;





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

  int g3_fields[] = {7,11,51,33,34,153,170,171,58,179};
  int n_g3_fields = 10;
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
  void dewpoint(float p, float t, float q, float *ptd);
  void rotLL_geo_to_ij(float lat_g_deg,float lon_g_deg,float lat_0_deg,float lon_0_deg,
		       float lat_g_SW_deg,float lon_g_SW_deg,float dx,
		       float *pxi,float *pxj);
  void rotLL_ij_to_geo(float i,float j,float lat_0_deg,float lon_0_deg,
		       float lat_g_SW_deg,float lon_g_SW_deg,float dxy_km,
		       float *lat_g_deg,float *lon_g_deg);
  double rotLL_wind2true_deg(double lat_g_deg,double lon_g_deg,
			     double lat_0_deg,double lon_0_deg);
  long my_interp(float fact,long x0,long x1);
  long my_dir_interp(float fact,long x0, long x1);
  time_t makeSecs(int year, int julday, int hour);
  int agrib_(int *nz_ptr, int *n_g3_fields,int *g3_fields,
	     int *n_g2_fields,int *g2_fields,
	     float *G3, float *G2,int *i_column,int *j_column,
	     char *filename, int *istatus_ptr );
  int read_airports(AIRPORT *p[],int max, char *filename,
		    int* max_id);

  /*  if(argc != 6) {
    printf("Usage: rotLL_soundings.x model filename grib_type grid_type tmp_file station_file\n");
    printf("Xue argc \n");
    exit(1);
    }*/
  model = argv[arg_i++];
  filename = argv[arg_i++];
  (void)sscanf(argv[arg_i++],"%d",&grib_type);
  (void)sscanf(argv[arg_i++],"%d",&grid_type);
  out_filename = argv[arg_i++];
  station_file = argv[arg_i++];
  (void)sscanf(argv[arg_i++],"%i",&hydro);

  if(hydro == 0) {
    n_g3_fields = 5;
  } else {
    n_g3_fields = 10;
  }

  /* if dx == 0, we have a lat/lon grid */
  if(grid_type == 20) {
    /* we have the OLD rotated lat/lon grid */
    lat_0_deg = 47.5;
    lon_0_deg = -104.;
    lat_g_SW_deg = 2.227524;
    lon_g_SW_deg = -140.4815;
    dxLL = 13.54508;
    nxLL = 758;
    nyLL = 567;
    nzLL = 39;
    dx = dxLL;
    nx = nxLL;
    ny = nyLL;
    nz = nzLL;          /* not needed, since n_g3_fields = 0. */
  } else if(grid_type == 21) {
    /* we have the NEW rotated lat/lon grid */
    lat_0_deg = 54.0;
    lon_0_deg = -106.0;
    lat_g_SW_deg =  -10.5906;
    lon_g_SW_deg = -139.0858;
    dxLL = 13.54508;
    nxLL = 953;
    nyLL = 834;
    nzLL = 39;
    dx = dxLL;
    nx = nxLL;
    ny = nyLL;
    nz = nzLL;          /* not needed, since n_g3_fields = 0. */
  }

    /* SET UP FOR 27 km ROTATED LAT/LON GRID */
  /*if(strncmp(model,"RR2", strlen("RR2")) == 0) {
    lat_0_deg = 47.5;
    lon_0_deg = -104.;
    lat_g_SW_deg = 2.4108;
    lon_g_SW_deg = -140.418;
    dx = 27.09017;
    nx = 378;
    ny = 283;
    nz = 50;
    printf("\n27km ROTATED LAT-LON GRID HARDWIRED FOR THIS RUN\n\n");
  }*/
  
  /* put dx in meters */
  dx *= 1000;

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
    snprintf(line,500,"./make_grib2_iso_tmp_file.pl %s %s %d %d",
	     filename,out_filename,hydro,nz);
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
  printf("%.3f sec for agrib.x\n",endSecs);

  /* loop over airports */
  for(i_apt=1;i_apt<n_airports;i_apt++) {
    ap = AIRPORTS[i_apt];
    alat = ap->lat;
    elon = ap->lon;
    printf("lat = %f, lon = %f, spacing (from file) = %f\n",alat,elon,dx);
    printf("station info: %s (%d) at %.0f meters elevation\n",
	   ap->name,ap->id,ap->elev);
  
    /* get the appropriate i,j */
    rotLL_geo_to_ij(alat,elon,lat_0_deg,lon_0_deg,
		    lat_g_SW_deg,lon_g_SW_deg,dx/1000,&ycart,&xcart);
    printf("xcart,ycart = %f %f\n",xcart,ycart);
    /* get x,y point */
    startx = (int)(xcart+0.5);
    starty = (int)(ycart+0.5);
    if(startx < 0 || startx >= nx ||
       starty < 0 || starty >= ny) {
      printf("out of domain \n");
      continue;
    }
    rotLL_ij_to_geo(starty,startx,lat_0_deg,lon_0_deg,
		    lat_g_SW_deg,lon_g_SW_deg,dx/1000,
		    &grid_lat,&grid_lon);
    printf("grid lat lon = %.3f %.3f\n",grid_lat,grid_lon);
    delta_north = (grid_lat - alat)*59.9; /* nautical miles */
    delta_east = (grid_lon - elon)*cos(alat * 0.0175)*59.9; /* nm  */
    printf("delta_east= %f delta_north= %f\n",
	   delta_east,delta_north);
    /* rotate direction appropriately for the rotLL grid */
    /* this means that S winds near the E coast need to pick up
       an W component wrt true N.  So rotate the wind vectors
       clockwise (+) near the E coast.
    */
    theta = rotLL_wind2true_deg(alat,elon,lat_0_deg,lon_0_deg);
    printf("here0\n");

  j_mand=0;
  last_pressure = 99999;
  icount = 0;			/* counts output levels */
   for(i=0;i<nz;i++) {
     field_index = 0;
     /*P =   g3[startx + nx*(starty + ny*(i + nz*field_index++))];*/
     pr =   1000*10 - i*25*10; /* mb * 10 */
     Z =   g3[startx + nx*(starty + ny*(i + nz*field_index++))];
     T =   g3[startx + nx*(starty + ny*(i + nz*field_index++))];
     RH =   g3[startx + nx*(starty + ny*(i + nz*field_index++))]/100;
     U =   g3[startx + nx*(starty + ny*(i + nz*field_index++))];
     V =   g3[startx + nx*(starty + ny*(i + nz*field_index++))];
     lnCLWMR = MISSING;
     lnRWMR = MISSING;
     lnSNMR = MISSING;
     lnICMR = MISSING;
     lnGRMR = MISSING;
     if(hydro == 1) {
       CLWMR = g3[startx + nx*(starty + ny*(i + nz*field_index++))];
       if(CLWMR > 1.1e-12) {
         lnCLWMR = log(CLWMR)*10;
       }
       RWMR = g3[startx + nx*(starty + ny*(i + nz*field_index++))];
       if(RWMR > 1.1e-12) {
         lnRWMR = log(RWMR)*10;
       }
       SNMR = g3[startx + nx*(starty + ny*(i + nz*field_index++))];
       if(SNMR > 1.1e-12) {
         lnSNMR = log(SNMR)*10;
       }
       ICMR = g3[startx + nx*(starty + ny*(i + nz*field_index++))];
       if(ICMR > 1.1e-12) {
         lnICMR = log(ICMR)*10;
       }
       GRMR = g3[startx + nx*(starty + ny*(i + nz*field_index++))];
       if(GRMR > 1.1e-12) {
         lnGRMR = log(GRMR)*10;
       }
     }
     /*pr=P/10 + 0.5;*/		/* convert to millibars times 10 */
     printf("lev %d, Z: %.6g, T: %.2f, RH: %.2g, U: %.2g, V: %.2g\n",
       i+1,Z,T,RH,U,V);
     dewpoint(pr*10,T,RH,&td_kelvin);
     t_kelvin = T;
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
      /* 
        if(raob_data[i].grmr != MISSING) {
	 fprintf(stderr,"igroupel for %s: %ld, %ld\n",
		 ap->name,raob_data[i].icmr ,raob_data[i].grmr);
       }
       */
    }
   }
   printf("End hydrometeor data\n");
}
  return 1;			/* keep lint happy (main defined to return int */
}
/**********************************************************************/

void dewpoint(float p, float tk, float rh, float *ptd) {
  /* ;;returns dewpoint in kelvin,
 *      ;; given pressure in pascals, temp in kelvin
 *           ;; and relative humidity
 *                */

  double esw_pascals,e_pascals,log10_e,dewpoint;
  double exnr,cpd_p,rovcp_p,pol,q;
  double tx,e,exner;

  /*
 *   cpd_p=1004.686;
 *     rovcp_p=0.285714;             
 *       exner = cpd_p*pow((p/100000.),rovcp_p);
 *         q = qv/(1.+qv);
 *           tk = vpt*exner/(cpd_p*(1.+0.6078*q));
 *             */


  /* Stan's way of calculating sat vap pressure: 
 *   tx = tk-273.15;
 *     pol = 0.99999683       + tx*(-0.90826951e-02 +
 *           tx*(0.78736169e-04   + tx*(-0.61117958e-06 +
 *                 tx*(0.43884187e-08   + tx*(-0.29883885e-10 +
 *                       tx*(0.21874425e-12   + tx*(-0.17892321e-14 +
 *                             tx*(0.11112018e-16   + tx*(-0.30994571e-19)))))))));
 *                               esw_old_pascals = 6.1078/pow(pol,8.) *100.; 
 *                                 */

  /* Rex's way of calculating sat vap pressure: */
  /* From Fan and Whiting (1987) as quoted in Fleming (1996): BAMS 77, p
 *      2229-2242, the saturation vapor pressure is given by: */
  /*
 *   esw_pascals=pow(10.,((10.286*tk - 2148.909)/(tk-35.85)));
 *     e = p*qv/(0.62197+qv);
 *       rh = e/esw_pascals;
 *         */
  /*printf("Temp: %f, rh %f Saturation: old,new= %f %f\n",
 *          tx,rh,esx,esw_pascals);*/
  if(rh > 0) {
    esw_pascals=pow(10.,((10.286*tk - 2148.909)/(tk-35.85)));
    e_pascals = rh*esw_pascals;
    log10_e = log10(e_pascals);

    /* invert the formula for esw to see the temperature at which
 *        e is the saturation value */

    dewpoint = (float)((-2148.909 + 35.85*log10_e)/(-10.286 + log10_e));
    /*
 *     printf("rh: %f, tk: %f. p: %f, dew: %f\n",
 *                rh,tk,p,dewpoint);
 *                    */
  } else {
    dewpoint = MISSING;
  }
  *ptd = dewpoint;
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
  
