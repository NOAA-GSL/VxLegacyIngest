import lib.*;
import sdg.*;
import java.util.*;
import java.lang.*;
import java.sql.*;

/** 
*
* updated to Stability2 to have levels
* at surface, at mandatory levels, and on
* integral 10 mb levels
* Aug 2006, WRM
*/
public class Stability2 extends Object {
  int n_levels;
  double pres[];
  double z[];
  double temp[];
  double parcel_temp[];
  int CACIn_flag[];		// 1 for CAPE, -1 for CIn, else 0
  double dewpt[];
  double rh[];
  double rhot[];		// RH with respect to observed T
  double wd[];
  double ws[];
  double Parcel_theta_e;
  double p_boundary, t_parcel, td_parcel, p_parcel;
  int presEPL;
  int presAtLCL;
  int i_850;
  int i_700;
  int i_500;
  int mb_inc = 10;		// mb increment in levels
  float mb_wanted = 0;
  float mand_level[] = {1000.f,925.f,850.f,700.f,500.f,400.f,300.f,250.f,150.f,100.f};
  float max_mb_gap = 150;	// don't interpolate across more than this.
  boolean leave_gap = false;
  boolean put_out_level = true;
  boolean no_dewpoint = false;
  String rh_calculator;

  /**
   * get a pre-existing stability from the database
   */
public Stability2(Statement stmt,String model,String site,int wmoid,
		  int fcst_len,UTCDate date) throws SQLException {
  Vector pressv = new Vector();
  Vector obTv = new Vector();
  String fcst_len_str = "is null";
  if(!model.equals("RAOB")) {
    fcst_len_str = "= "+fcst_len;
  }
  String query =
    "select press,t/100 as t from ruc_ua."+model+"\n"+
    "where fcst_len "+fcst_len_str+"\n"+
    "and wmoid = "+wmoid+"\n"+
    "and hour = "+date.getHour()+"\n"+
    "and date = '"+date.getSQLDate()+"'\n"+
    "order by press desc\n";
  //Debug.println(query);
  ResultSet rs = stmt.executeQuery(query);
  while(rs.next()) {
    String ps = rs.getString("press");
    String ts = rs.getString("t");
    pressv.addElement(ps);
    obTv.addElement(ts);
  }
  n_levels = pressv.size();
  pres = new double[n_levels];
  temp = new double[n_levels];
  Enumeration ep = pressv.elements();
  Enumeration et = obTv.elements();
  int i=0;
  while(ep.hasMoreElements()) {
    String ps = (String)ep.nextElement();
    if(ps == null) {
      pres[i] = Sounding.MISSING;
    } else {
      pres[i] = Double.parseDouble(ps);
    }
    String ts = (String)et.nextElement();
    if(ts == null) {
      temp[i] = Sounding.MISSING;
    } else {
      temp[i] = Double.parseDouble(ts);
    }
    i++;
  }
 }

/**
 * generate a Stability from a Sounding
 */
public Stability2(Sounding s, String rh_calculator) {
  this.rh_calculator = rh_calculator;
   this.n_levels = s.n_levels;
    if(s.n_levels <= 0) {
      Debug.println("returning (1) with "+s.n_levels+" levels");
      return;
    }
    Hashtable sint = new Hashtable();

    SoundingLevel lev=null;
    SoundingLevel last_lev=null;
    SoundingLevel s_lev=null;
    float interp_p,interp_z,interp_t,interp_dp,interp_wd,interp_ws,fact;
    int j,k;
    boolean done;

    // INTERPOLATE TEMPERATURE
    j=0;
    k=0;
    done = false;
    while(!done && k<s.n_levels) {
      last_lev = (SoundingLevel)s.level.elementAt(k++);
      if(last_lev.p  != Sounding.MISSING &&
	 last_lev.t != Sounding.MISSING
	 ) {
	done=true;
	//Debug.println("zeroth level at "+last_lev);
	sint.put(last_lev.p,new SoundingLevel(j++,last_lev.p,
					  last_lev.z,last_lev.z_gps,
					  last_lev.ice,
					  last_lev.t,
					  last_lev.dp,last_lev.dpUnc,
					  last_lev.wd,last_lev.ws,0,0,null,
					  last_lev.data_descriptor));
      }
    }

    //    Debug.println("Xue in Stability2 last_lev z="+last_lev.z+" p="+last_lev.p);
    if(done) {
      // we found a starting level and can start interpolating
      // set a starting level, on a mb_inc boundary
      mb_wanted = last_lev.p - last_lev.p%mb_inc;
      if(Math.abs(mb_wanted - last_lev.p) < 1e-10) {
	mb_wanted = last_lev.p - mb_inc;
      }
      // we're now on a mb_inc mb boundry
      // set next lev = last_lev to force reading a new level below
      lev = last_lev;
      while(mb_wanted > 0) {

      // is lev above mb_wanted
      if(lev.p < mb_wanted) {
	// it is.  interpolate output level
	// if the existing levels are close enuf together
	if(last_lev.p - lev.p > max_mb_gap) {
	  leave_gap = true;
	} else {
	  leave_gap = false;
	}
	if(!leave_gap) {
	  put_out_level = true;
	} else {
	  if(last_lev.p - mb_wanted < mb_inc) {
	    put_out_level = true;
	  } else if(mb_wanted - lev.p < mb_inc) {
	    put_out_level = true;
	  } else {
	    put_out_level = false;
	  }
	}
	if(put_out_level) {
	  fact=(float)
	    ((Math.log(last_lev.p)-Math.log(mb_wanted)) /
	     (Math.log(last_lev.p)-Math.log(lev.p)));
	  interp_z=my_interp(fact,last_lev.z,lev.z);
	  interp_t=my_interp(fact,last_lev.t,lev.t);
	  /*
	  interp_dp=my_interp(fact,last_lev.dp,lev.dp);
	  */
	  SoundingLevel int_lev =
	    new SoundingLevel(j++,mb_wanted,interp_z,
			      interp_t,Sounding.MISSING,
			      Sounding.MISSING,Sounding.MISSING);
	  sint.put(mb_wanted,int_lev);
	}
	mb_wanted -= mb_inc;
      } else {
	// lev.p is below mb_wanted.  bring in new level
	// but first, put out this level if its mandatory
	for(int i=0;i<mand_level.length;i++) {
	  if(Math.abs(lev.p - mand_level[i]) < 1e-10) {
	    // it is.  put it out
	    sint.put(lev.p,new SoundingLevel(j++,lev.p,lev.z,
					      lev.t,lev.dp,
					      lev.wd,lev.ws));
	    //	    Debug.println("Xue in Stability2 mand level "+j+" at "+lev);
	    if(Math.abs(lev.p - mb_wanted) < 0.5) {
	      // don't put out mandatory levels twice
	      mb_wanted -= mb_inc;
	    }
	    break;
	  }
	}
	last_lev = lev;
	// find next level with good t
	boolean found_t = false;
	while(k<s.n_levels) {
	  lev = (SoundingLevel)s.level.elementAt(k++);
	  if(lev.t != Sounding.MISSING &&
	     lev.p != Sounding.MISSING) {
	    //Debug.println("2 found lev: "+lev);
	    found_t = true;
	    break;
	  }
	}
	if(!found_t) {
	  // no more input levels
	  break;
	}
      }
    }
    }

    // INTERPOLATE dewpoint
    j=0;
    k=0;
    done = false;
    while(!done && k<s.n_levels) {
      last_lev = (SoundingLevel)s.level.elementAt(k++);
      if(last_lev.p  != Sounding.MISSING &&
	 last_lev.dp != Sounding.MISSING &&
	 last_lev.t != Sounding.MISSING
	 ) {
	done=true;
	// this level will already be in sint, if both t and dp existed
	SoundingLevel this_lev = (SoundingLevel)sint.get(last_lev.p);
	if(this_lev != null) {
	  // add dewpoint
	  this_lev.dp = last_lev.dp;
	}
      }
    }
    if(done) {
      // we found a starting level and can start interpolating
      // set a starting level, on a mb_inc boundary
      mb_wanted = last_lev.p - last_lev.p%mb_inc;
      if(Math.abs(mb_wanted - last_lev.p) < 1e-10) {
	mb_wanted = last_lev.p - mb_inc;
      }
      // we're now on a mb_inc mb boundry
      // set next lev = last_lev to force reading a new level below
      lev = last_lev;
      while(mb_wanted > 0) {
	
	// is lev above mb_wanted
      if(lev.p < mb_wanted) {
	// it is.  interpolate output level
	// if the existing levels are close enuf together
	if(last_lev.p - lev.p > max_mb_gap) {
	  leave_gap = true;
	} else {
	  leave_gap = false;
	}
	if(!leave_gap) {
	  put_out_level = true;
	} else {
	  if(last_lev.p - mb_wanted < mb_inc) {
	    put_out_level = true;
	  } else if(mb_wanted - lev.p < mb_inc) {
	    put_out_level = true;
	  } else {
	    put_out_level = false;
	  }
	}
	if(put_out_level) {
	  fact=(float)
	    ((Math.log(last_lev.p)-Math.log(mb_wanted)) /
	     (Math.log(last_lev.p)-Math.log(lev.p)));
	  interp_dp=my_interp(fact,last_lev.dp,lev.dp);
	  
	  SoundingLevel int_lev = (SoundingLevel)sint.get(mb_wanted);
	  int_lev.dp = interp_dp;
	}
	mb_wanted -= mb_inc;
      } else {
	// lev.p is below mb_wanted.  bring in new level
	last_lev = lev;
	// find next level with good t
	boolean found_t = false;
	while(k<s.n_levels) {
	  lev = (SoundingLevel)s.level.elementAt(k++);
	  if(lev.t != Sounding.MISSING &&
	     lev.dp != Sounding.MISSING &&
	     lev.p != Sounding.MISSING) {
	    //Debug.println("2 found lev: "+lev);
	    found_t = true;
	    break;
	  }
	}
	if(!found_t) {
	  // no more input levels
	  break;
	}
      }
    }
    }

    /* for debugging:
    Enumeration en = sint.elements();
    while(en.hasMoreElements()) {
      SoundingLevel elev = (SoundingLevel)en.nextElement();
      Debug.println(""+elev);
    }
    */
     // INTERPOLATE winds
    j=0;
    k=0;
    done = false;
    while(!done && k<s.n_levels) {
      last_lev = (SoundingLevel)s.level.elementAt(k++);
      if(last_lev.p  != Sounding.MISSING &&
	 last_lev.ws != Sounding.MISSING &&
	 last_lev.wd != Sounding.MISSING
	 ) {
	done=true;
	// get this level
	SoundingLevel this_lev = (SoundingLevel)sint.get(last_lev.p);
	if(this_lev != null) {
	  // add winds
	  this_lev.wd = last_lev.wd;
	  this_lev.ws = last_lev.ws;
	} else {
	  // create and add this level
	  this_lev =
	    new SoundingLevel(j++,last_lev.p,
			      last_lev.z,last_lev.z_gps,
			      last_lev.ice,
			      last_lev.t,
			      last_lev.dp,last_lev.dpUnc,
			      last_lev.wd,last_lev.ws,0,0,null,
			      last_lev.data_descriptor);
	  sint.put(last_lev.p,this_lev);
	}
	//Debug.println("adding/changing level: "+lev);
      }
    }
    if(done) {
      // we found a starting level and can start interpolating
      // set a starting level, on a mb_inc boundary
      mb_wanted = last_lev.p - last_lev.p%mb_inc;
      if(Math.abs(mb_wanted - last_lev.p) < 1e-10) {
	mb_wanted = last_lev.p - mb_inc;
      }
      // we're now on a mb_inc mb boundry
      // set next lev = last_lev to force reading a new level below
      lev = last_lev;
      while(mb_wanted > 0) {
	
	// is lev above mb_wanted
      if(lev.p < mb_wanted) {
	// it is.  interpolate output level
	// if the existing levels are close enuf together
	if(last_lev.p - lev.p > max_mb_gap) {
	  leave_gap = true;
	} else {
	  leave_gap = false;
	}
	if(!leave_gap) {
	  put_out_level = true;
	} else {
	  if(last_lev.p - mb_wanted < mb_inc) {
	    put_out_level = true;
	  } else if(mb_wanted - lev.p < mb_inc) {
	    put_out_level = true;
	  } else {
	    put_out_level = false;
	  }
	}
	if(put_out_level) {
	  fact=(float)
	    ((Math.log(last_lev.p)-Math.log(mb_wanted)) /
	     (Math.log(last_lev.p)-Math.log(lev.p)));
	  interp_z=my_interp(fact,last_lev.z,lev.z);
	  interp_ws=my_interp(fact,last_lev.ws,lev.ws);
	  interp_wd=my_dir_interp(fact,last_lev.wd,lev.wd);
	  SoundingLevel int_lev = (SoundingLevel)sint.get(mb_wanted);
	  if(int_lev != null) {
	    int_lev.ws = interp_ws;
	    int_lev.wd = interp_wd;
	  } else {
	    // create and add this level
	    int_lev = new SoundingLevel(j++,mb_wanted,interp_z,
					Sounding.MISSING,Sounding.MISSING,
					interp_wd,interp_ws);
	    sint.put(mb_wanted,int_lev);
	  }
	  /*
	  Debug.println("interpolated level "+j
			+", between "+lev.p+" and "+last_lev.p
			+" "+int_lev);
	  */
	}
	mb_wanted -= mb_inc;
      } else {
	// lev.p is below mb_wanted.  bring in new level
	last_lev = lev;
	// find next level with good t
	boolean found_w = false;
	while(k<s.n_levels) {
	  lev = (SoundingLevel)s.level.elementAt(k++);
	  if(lev.ws != Sounding.MISSING &&
	     lev.wd != Sounding.MISSING &&
	     lev.p != Sounding.MISSING) {
	    //Debug.println("2 found lev: "+lev);
	    found_w = true;
	    break;
	  }
	}
	if(!found_w) {
	  // no more input levels
	  break;
	}
      }
    }
    }
    /* for debugging:
    en = sint.elements();
    while(en.hasMoreElements()) {
      SoundingLevel elev = (SoundingLevel)en.nextElement();
      Debug.println(""+elev);
    }
    */
    n_levels = sint.size();
    if(n_levels > 0) {
      pres = new double[n_levels];
      z = new double[n_levels];
      temp = new double[n_levels];
      parcel_temp = new double[n_levels];
      CACIn_flag = new int[n_levels];
      dewpt = new double[n_levels];
      rh = new double[n_levels];
      rhot = new double[n_levels];
      wd = new double[n_levels];
      ws = new double[n_levels];
      Vector v1 = new Vector(sint.keySet());
      Collections.sort(v1,Collections.reverseOrder());
      Iterator it1 = v1.iterator();
      int i=0;
      while(it1.hasNext()) {
	Float press = (Float)it1.next();
	lev = (SoundingLevel)sint.get(press);
	pres[i] = lev.p;
	z[i] = lev.z;
	temp[i] = lev.t;
	parcel_temp[i] = Sounding.MISSING;
	dewpt[i] = lev.dp;
	rhot[i] = Sounding.MISSING;
	if(lev.t != Sounding.MISSING &&
	   lev.dp != Sounding.MISSING) {
	  double tk = lev.t + 273.15;
	  double tdk = lev.dp + 273.15;
	  if(rh_calculator.equals("Fan-Whiting")) {
	    rh[i] = svpFW(tdk)/svpFW(tk) * 100;
	  } else if(rh_calculator.equals("Bolton")) {
	    rh[i] = svpBolton(tdk)/svpBolton(tk) * 100;
	  } else if(rh_calculator.equals("Wobus")) {
	    rh[i] = svpWobus(tdk)/svpWobus(tk) * 100;
	  } else if(rh_calculator.equals("GFS-fixer-Wobus")) {
	    // get reported GFS RH. (dp was calculated from RH with Fan-Whiting)
	    double rh_gfs = svpFW(tdk)/svpFW(tk)*100;
	    // get gfs Vapor Pressure
	    // (GFS actually defines RH as the ratio of specific humidities.
	    //  John assures me this is close enough to the ratio of vapor pressures)
	    double e_gfs = rh_gfs*svpGFS(tk)/100;
	    // get rh over LIQUID using Wobus
	    double rh_gfs_liq = e_gfs/svpWobus(tk)*100;
	    rh[i] = rh_gfs_liq;
	  } else if(rh_calculator.equals("FW-to-Wobus")) {
	    // reverse the way dewpoint was calculated from RUC
	    // to get RUC vapor pressure 
	    double e_ruc = svpFW(tdk);
	    // now calculate RH based on Wobus
	    rh[i] = e_ruc/svpWobus(tk)*100;
	  } else {
	    // use old (method, for consistency, until we find something better
	    rh[i] = Stability.satVapPres(tdk)/Stability.satVapPres(tk) * 100;
	  }
	  /*
	  // DEBUGGING CODE FOLLOWS:
	  int rh_FW = (int)(svpFW(tdk)/svpFW(tk) * 100 + 0.5);
	  int rh_Bolton = (int)(svpBolton(tdk)/svpBolton(tk) * 100 +0.5);
	  int rh_Wobus = (int)(svpWobus(tdk)/svpWobus(tk) * 100 + 0.5);
	  int rh_FWW = (int)(svpFW(tdk)/svpWobus(tk)*100 +0.5);
	  int rh_Guey = (int)(Stability.satVapPres(tdk)/Stability.satVapPres(tk) * 100 + 0.5);
	  Debug.println("wmoid "+s+", t "+MyUtil.goodRound(temp[i],1)+
			", rh "+MyUtil.goodRound(rh[i],0)+
			", rh_FW "+rh_FW+", rh_Bolton "+rh_Bolton+
			", rh_Wobus "+rh_Wobus+", rh_FWW "+rh_FWW+
			", rh_Guey "+rh_Guey);
	  */
	  if(rh[i] > 250) {
	    // do not exceed the database max of 256 for a tinyint unsigned
	    rh[i] = Sounding.MISSING;
	  }
	} else {
	  rh[i] = Sounding.MISSING;
	}
	if(lev.wd != Sounding.MISSING &&
	   lev.ws != Sounding.MISSING) {
	  wd[i] = lev.wd;
	  ws[i] = lev.ws*0.515;		// kts -> m/s
	} else {
	  wd[i] = Sounding.MISSING;
	  ws[i] = Sounding.MISSING;
	}
	i++;
      }
    }
}

public static float my_interp(float fact,float x0,float x1) {
  float result;
  if(x0 == Sounding.MISSING || x1 == Sounding.MISSING) {
    result=Sounding.MISSING;
  } else {
    result=x0 + fact*(x1 - x0);
  }
  return (result);
}

public static float my_dir_interp(float fact,float x0, float x1) {
  /* interpolates wind directions in the range 0 - 359 degrees */
  float result;
  float dir_dif;
  if(x0 == Sounding.MISSING || x1 == Sounding.MISSING) {
    result=Sounding.MISSING;
  } else {
    dir_dif = x1 - x0;
    if(dir_dif > 180) {
      dir_dif -= 360;
    } else if(dir_dif < -180) {
      dir_dif += 360;
    }
    result = x0 + fact*(dir_dif);
    if(result < 0) {
      result += 360;
    } else if(result > 360) {
      result -= 360;
    }
  }
  return (result);
}
  
  /* From FAN AND WHITING (1987) as quoted in Fleming (1996): BAMS 77, p
     2229-2242, the saturation vapor pressure is given by: */
public float svpFW(double tk) {
  float esw_pascals;
  esw_pascals=(float)Math.pow(10.,(10.286*tk - 2148.909)/(tk-35.85));
  return(esw_pascals);
}

  /** WOBUS
      
C	Baker, Schlatter  17-MAY-1982	  Original version.

C   THIS FUNCTION RETURNS THE SATURATION VAPOR PRESSURE ESW (MILLIBARS)
C   OVER LIQUID WATER GIVEN THE TEMPERATURE T (CELSIUS). THE POLYNOMIAL
C   APPROXIMATION BELOW IS DUE TO HERMAN WOBUS, A MATHEMATICIAN WHO
C   WORKED AT THE NAVY WEATHER RESEARCH FACILITY, NORFOLK, VIRGINIA,
C   BUT WHO IS NOW RETIRED. THE COEFFICIENTS OF THE POLYNOMIAL WERE
C   CHOSEN TO FIT THE VALUES IN TABLE 94 ON PP. 351-353 OF THE SMITH-
C   SONIAN METEOROLOGICAL TABLES BY ROLAND LIST (6TH EDITION). THE
C   APPROXIMATION IS VALID FOR -50 < T < 100C.
  */

static public float svpWobus(double tk) {
  double tx = tk-273.15;
  double pol = 0.99999683       + tx*(-0.90826951e-02 +
      tx*(0.78736169e-04   + tx*(-0.61117958e-06 +
      tx*(0.43884187e-08   + tx*(-0.29883885e-10 +
      tx*(0.21874425e-12   + tx*(-0.17892321e-14 +
      tx*(0.11112018e-16   + tx*(-0.30994571e-19)))))))));
  double  esw_pascals = 6.1078/Math.pow(pol,8.) *100.; 
  return((float)esw_pascals);
}
  
    /** BOLTON
      
C   THIS FUNCTION RETURNS THE SATURATION VAPOR PRESSURE ESBOL (Pascals) OVER
C   LIQUID WATER GIVEN THE TEMPERATURE T (CELSIUS). THE FORMULA APPEARS
C   IN BOLTON, DAVID, 1980: "THE COMPUTATION OF EQUIVALENT POTENTIAL
C   TEMPERATURE," MONTHLY WEATHER REVIEW, VOL. 108, NO. 7 (JULY),
C   P. 1047, EQ.(10). THE QUOTED ACCURACY IS 0.3% OR BETTER FOR
C   -35 < T < 35C.

for temperatures of down to -60 C, rh values calculated from this formula
differ from those calculated by Goff-Gratsch by < .05 %RH  - WRM 16 May 2008

C	Baker, Schlatter  17-MAY-1982	  Original version.
  */  
public float svpBolton(double tk) {
  double tc = tk-273.15;
  double esw_mb;
  esw_mb = 6.1121 * Math.exp(17.67*tc/(tc+243.5));
  double esw_pascals = esw_mb*100;
  return((float)esw_pascals);
}

  /** GOFF-GRATCH
      
C	Baker, Schlatter  17-MAY-1982	  Original version.

C   THIS FUNCTION RETURNS THE SATURATION VAPOR PRESSURE OVER LIQUID
C   WATER ESGG (Pascals) GIVEN THE TEMPERATURE T (CELSIUS). THE
C   FORMULA USED, DUE TO GOFF AND GRATCH, APPEARS ON P. 350 OF THE
C   SMITHSONIAN METEOROLOGICAL TABLES, SIXTH REVISED EDITION, 1963,
C   BY ROLAND LIST.

adapted for java by WR Moninger, 2008.
boiling point changed from 373.15 to 373.16 -- 30-May-2008
  */
static public float svpGG(double tk) {
  double ts = 373.16;		// boiling point of water
  double c1 = 7.90298;
  double c2 = 5.02808;
  double c3 = 1.3816E-7;
  double c4 = 11.344;
  double c5 = 8.1328E-3;
  double c6 = 3.49149;
  double ews = 1013.246;	// SATURATION VAPOR PRESSURE (MB) OVER LIQUID WATER AT 100C

  double exponent =
    - c1*(ts/tk-1.)+c2*Math.log(ts/tk)/Math.log(10.)
    - c3*(Math.pow(10.,(c4*(1.-tk/ts)))-1.)
    + c5*(Math.pow(10.,(-c6*(ts/tk-1.)))-1.)
    + Math.log(ews)/Math.log(10);
  double esw = Math.pow(10.,exponent);
  if(esw < 0) {
    esw = 0;
  }
  return((float)(esw*100.));
}

  /** GFS ICE-LIQUID SVP
      
       elemental function fpvsnew(t)
!$$$     Subprogram Documentation Block
!
! Subprogram: fpvsnew         Compute saturation vapor pressure
!   Author: N Phillips            w/NMC2X2   Date: 30 dec 82
!
! Abstract: Compute saturation vapor pressure from the temperature.
!   A linear interpolation is done between values in a lookup table
!   computed in gpvs. See documentation for fpvsx for details.
!   Input values outside table range are reset to table extrema.
!   The interpolation accuracy is almost 6 decimal places.
!   On the Cray, fpvs is about 4 times faster than exact calculation.
!   This function should be expanded inline in the calling routine.
!
! Program History Log:
!   91-05-07  Iredell             made into inlinable function
!   94-12-30  Iredell             expand table
! 1999-03-01  Iredell             f90 module
! 2001-02-26  Iredell             ice phase
!
! Usage:   pvs=fpvsnew(t)
!
!   Input argument list:
!     t          Real(krealfp) temperature in Kelvin
!
!   Output argument list:
!     fpvsnew       Real(krealfp) saturation vapor pressure in Pascals
!
! Attributes:
!   Language: Fortran 90.
!
!$$$

Adapted to java by WR Moninger, May 2008
*/
static float svpGFS(double t) {
  final double con_ttp     =2.7316e+2; // temp at H2O 3pt
  final double con_psat    =6.1078e+2; // pres at H2O 3pt
  final double con_cvap    =1.8460e+3; // spec heat H2O gas   (J/kg/K)
  final double con_cliq    =4.1855e+3; // spec heat H2O liq
  final double con_hvap    =2.5000e+6; // lat heat H2O cond
  final double con_rv      =4.6150e+2; // gas constant H2O
  final double con_csol    =2.1060e+3; // spec heat H2O ice
  final double con_hfus    =3.3358e+5; // lat heat H2O fusion;
  final double tliq=con_ttp;
  //final double tliq=0; // use this to approximate svp over liquid
  final double tice=con_ttp-20.0;
  final double dldtl=con_cvap-con_cliq;
  final double heatl=con_hvap;
  final double xponal=-dldtl/con_rv;
  final double xponbl=-dldtl/con_rv+heatl/(con_rv*con_ttp);
  final double dldti=con_cvap-con_csol;
  final double heati=con_hvap+con_hfus;
  final double xponai=-dldti/con_rv;
  final double xponbi=-dldti/con_rv+heati/(con_rv*con_ttp);
  double tr,w,pvl,pvi;
  double fpvsnew;
  int jx;
  double  xj,x,xp1;
  final int nxpvs = 7501;
  double[] tbpvs = new double[nxpvs];
  double xmin,xmax,xinc,c2xpvs,c1xpvs;

  xmin=180.0;
  xmax=330.0;
  xinc=(xmax-xmin)/(nxpvs-1);
  c2xpvs=1./xinc;
  c1xpvs=1.-xmin*c2xpvs;
  xj=Math.min(Math.max(c1xpvs+c2xpvs*t,1.0),nxpvs);
  jx=(int)Math.min(xj,nxpvs-1.0);
  x=xmin+(jx-1)*xinc;

  tr=con_ttp/x;
  if(x >= tliq) {
    tbpvs[jx]=con_psat*Math.pow(tr,xponal)*Math.exp(xponbl*(1.-tr));
  } else if(x < tice) {
    tbpvs[jx]=con_psat*Math.pow(tr,xponai)*Math.exp(xponbi*(1.-tr));
  } else {
    w=(t-tice)/(tliq-tice);
    pvl=con_psat*Math.pow(tr,xponal)*Math.exp(xponbl*(1.-tr));
    pvi=con_psat*Math.pow(tr,xponai)*Math.exp(xponbi*(1.-tr));
    tbpvs[jx]=w*pvl+(1.-w)*pvi;
  }

  xp1=xmin+(jx-1+1)*xinc;

  tr=con_ttp/xp1;
  if(xp1 > tliq) {
    tbpvs[jx+1]=con_psat*Math.pow(tr,xponal)*Math.exp(xponbl*(1.-tr));
  } else if(xp1 < tice) {
    tbpvs[jx+1]=con_psat*Math.pow(tr,xponai)*Math.exp(xponbi*(1.-tr));
  } else {
    w=(t-tice)/(tliq-tice);
    pvl=con_psat*Math.pow(tr,xponal)*Math.exp(xponbl*(1.-tr));
    pvi=con_psat*Math.pow(tr,xponai)*Math.exp(xponbi*(1.-tr));
    tbpvs[jx+1]=w*pvl+(1.-w)*pvi;
  }
  
  fpvsnew=tbpvs[jx]+(xj-jx)*(tbpvs[jx+1]-tbpvs[jx]);
  return((float)fpvsnew);
}
      
}
/*
Open Source License/Disclaimer, 
Forecast Systems Laboratory
NOAA/OAR/FSL
325 Broadway Boulder, CO 80305 

This software is distributed under the Open Source Definition, which
may be found at http://www.opensource.org/osd.html. In particular,
redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:  
<ul>
<li> Redistributions of source code must retain this notice, this list of
  conditions and the following disclaimer. 

<li> Redistributions in binary form must provide access to this notice,
  this list of conditions and the  following disclaimer, and the
  underlying source code.
  
<li> All modifications to this software must be clearly documented, and
  are solely the responsibility of the agent making the
  modifications.
  
<li> If significant modifications or enhancements are made to this
  software, the FSL Software Policy Manager (softwaremgr@fsl.noaa.gov)
  should be notified.
</ul>
    
THIS SOFTWARE AND ITS DOCUMENTATION ARE IN THE PUBLIC DOMAIN AND ARE
FURNISHED "AS IS." THE AUTHORS, THE UNITED STATES GOVERNMENT, ITS
INSTRUMENTALITIES, OFFICERS, EMPLOYEES, AND AGENTS MAKE NO WARRANTY,
EXPRESS OR IMPLIED, AS TO THE USEFULNESS OF THE SOFTWARE AND
DOCUMENTATION FOR ANY PURPOSE. THEY ASSUME NO RESPONSIBILITY (1) FOR THE
USE OF THE SOFTWARE AND DOCUMENTATION; OR (2) TO PROVIDE TECHNICAL
SUPPORT TO USERS. 
*/
	
