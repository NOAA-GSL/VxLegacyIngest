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
package sdg;
	
import lib.*;
import java.util.*;
import java.lang.*;

/* from
   Tom Whittaker (tomw@ssec.wisc.edu)
University of Wisconsin-Madison
Space Science and Engineering Center
Phone/VoiceMail: 608/262-2759
Fax: 608/263-6738
*/


/** an idea of a Sounding class
*
*/
public class Stability extends Object {
  int n_levels;
  double pres[];
  double temp[];
  double parcel_temp[];
  int CACIn_flag[];		// 1 for CAPE, -1 for CIn, else 0
  double dewpt[];
  double wd[];
  double ws[];
  double Parcel_theta_e;
  double p_boundary, t_parcel, td_parcel, p_parcel;
  int presEPL;
  int presAtLCL;
  int i_850;
  int i_700;
  int i_500;
  boolean no_dewpoint=true;

public Stability(Sounding s) {
   this.n_levels = s.n_levels;
    if(s.n_levels <= 0) {
      Debug.println("returning (1) with "+s.n_levels+" levels");
      return;
    }
    Vector sint = new Vector(50);

    SoundingLevel lev=null;
    SoundingLevel last_lev=null;
    SoundingLevel s_lev=null;
    float interp_p,interp_z,interp_t,interp_dp,interp_wd,interp_ws,fact;
    i_850=-1;
    i_700=-1;
    i_500=-1;
    int j=0;
    int k=0;
    boolean done=false;
    no_dewpoint = true;
    // zeroth level of interpolated sounding
    while(!done && k<s.n_levels) {
      last_lev = (SoundingLevel)s.level.elementAt(k++);
      Debug.println("zeroth level at "+last_lev);
      if(last_lev.p  != Sounding.MISSING &&
	 //last_lev.dp  != Sounding.MISSING &&
	 last_lev.t != Sounding.MISSING
	 ) {
	done=true;
	sint.addElement(new SoundingLevel(j++,last_lev.p,
					  last_lev.z,last_lev.z_gps,
					  last_lev.t,
					  last_lev.dp,last_lev.dpUnc,
				       last_lev.wd,last_lev.ws,0,0,null,
				       last_lev.data_descriptor));
      }
    }
    //if we didn't find a zeroth level, quit
    if(!done) {
      Debug.println("returning (2) with 0 levels");
      this.n_levels=0;
      return;
    }
    // interpolate levels at least every min_delta
    double min_delta = 20.0;
    while(k<s.n_levels) {
      lev = (SoundingLevel)s.level.elementAt(k);
      if(lev.p  != Sounding.MISSING &&
	 //lev.dp  != Sounding.MISSING &&
	 lev.t != Sounding.MISSING) {
	//check that we have any dewpoint info
	if(lev.dp != Sounding.MISSING) {
	  no_dewpoint = false;
	}
	double delta_mb = last_lev.p - lev.p;
	if(delta_mb > min_delta) {
	  //interpolate levels
	  int n_interp = (int)(delta_mb/min_delta);
	  float delta_interp = (float)(delta_mb/(n_interp+1));
	  float mb = last_lev.p;
	  for(int i=0;i<n_interp;i++) {
	    mb -= delta_interp;
	    //create a new interpolated level
	    fact=(float)
	      ((Math.log(last_lev.p)-Math.log(mb)) /
		(Math.log(last_lev.p)-Math.log(lev.p)));
	    interp_z=my_interp(fact,last_lev.z,lev.z);
	    interp_t=my_interp(fact,last_lev.t,lev.t);
	    interp_dp=my_interp(fact,last_lev.dp,lev.dp);
	    interp_ws=my_interp(fact,last_lev.ws,lev.ws);
	    interp_wd=my_dir_interp(fact,last_lev.wd,lev.wd);
	    sint.addElement(
	       new SoundingLevel(j++,mb,interp_z,interp_t,interp_dp,
				 interp_wd,interp_ws));
	  }
	}
	sint.addElement(
	       new SoundingLevel(j++,lev.p,lev.z,lev.t,lev.dp,
				 lev.wd,lev.ws));
	last_lev=lev;
      }
      k++;
    }
    this.n_levels = j-1;
    //now add winds (they're at separate levels for RAOBS
    SoundingLevel lower_lev=null;
    SoundingLevel upper_lev=null;
    for(int i=0;i<this.n_levels;i++) {
      lev = (SoundingLevel)sint.elementAt(i);
      if(lev.wd == Sounding.MISSING ||
	 lev.ws == Sounding.MISSING) {
	//find good wind levels in the original sounding that bracket this
	boolean levels_found=false;
	lower_lev=null;
	upper_lev=null;
	for(j=0;j<s.n_levels;j++) {
	  s_lev = (SoundingLevel) s.level.elementAt(j);
	  if(s_lev.p < lev.p &&
	     s_lev.ws != Sounding.MISSING) {
	    upper_lev = s_lev;
	    if(lower_lev != null) {
	      levels_found=true;
	    }
	    break;
	  }
	  if(s_lev.ws != Sounding.MISSING) {
	    lower_lev = s_lev;
	  }
	}
	if(!levels_found) {
	  break;
	}
	//we have a level above and below, so can interpolate
	fact=(float)
	  ((Math.log(lower_lev.p)-Math.log(lev.p)) /
	   (Math.log(lower_lev.p)-Math.log(upper_lev.p)));
	interp_ws=my_interp(fact,lower_lev.ws,upper_lev.ws);
	interp_wd=my_dir_interp(fact,lower_lev.wd,upper_lev.wd);
	sint.setElementAt(
	   new SoundingLevel(lev.n_level,lev.p,lev.z,lev.t,lev.dp,
			     interp_wd,interp_ws),i);
      }
    }

    //so we should have good temperatures AND winds at every level now.
    Debug.println("here 4, n_levels = "+n_levels);  
    if(n_levels > 1) {
      pres = new double[n_levels];
      temp = new double[n_levels];
      parcel_temp = new double[n_levels];
      CACIn_flag = new int[n_levels];
      dewpt = new double[n_levels];
      wd = new double[n_levels];
      ws = new double[n_levels];
      for(int i=0;i<n_levels;i++) {
	lev = (SoundingLevel)sint.elementAt(i);
	pres[i] = lev.p;
	temp[i] = cent_to_kelvin(lev.t);	// in Kelvin
	parcel_temp[i] = Sounding.MISSING;
	dewpt[i] = cent_to_kelvin(lev.dp); // ditto
	wd[i] = lev.wd;
	ws[i] = lev.ws;		// in kts
	if(lev.p == 850) i_850=i;
	if(lev.p == 700) i_700=i;
	if(lev.p == 500) i_500=i;
	//Debug.println(""+lev);
      }
      // if there' no 850 level, use a level 75 mb above the surface
      if(i_850 == -1) {
	double pres_in_mixed_layer = pres[0]-75;
	for(int i=1;i<n_levels;i++) {
	  if(pres[i] < pres_in_mixed_layer) {
	    i_850 = i;
	    Debug.println("850 level faked at i = "+i+" = "+pres[i]+" mb");
	    break;
	  }
	}
      }
    }
}

public String toString() {
  String out="";
  out+="total totals is "+totalTotals()+"\n";
  out+="LI is "+liftedIndex()+"\n";
  out+="K index is "+kIndex()+"\n";
  out+="Showalter is "+showalter()+"\n";
  out+="Sweat Index is "+sweat()+"\n";
  out+="Parcel (100mb thick) LCL is "+presLCL()+"mb\n";
  out+="Level of free convection is "+presLFC()+"mb\n";
  out+="Equilibrium pressure level is "+presEP()+"mb\n";
  return out;
}

public double cent_to_kelvin(double cent) {
  double result;
  if(cent != Sounding.MISSING) {
    result = cent + 273.15;
  } else {
    result = Sounding.MISSING;
  }
  return result;
}
  
public int sweat() {
    int sweat = Sounding.MISSING;
    if(no_dewpoint || n_levels <= 0) {
      return sweat;
    }

      if (i_850 >=0 && i_500 >= 0) {
	if(
	   ws[i_850] != Sounding.MISSING &&
	   wd[i_850] != Sounding.MISSING &&
	   ws[i_500] != Sounding.MISSING &&
	   wd[i_500] != Sounding.MISSING) {
	  double sss = Math.sin((wd[i_500] - wd[i_850])/57.3);
	  double sh_term = 125*(sss+0.2);
	  // shear term set to zero if:
	  if(wd[i_850] < 130 || wd[i_850] > 250) sh_term=0;
	  if(wd[i_500] < 210 || wd[i_500] > 310) sh_term=0;
	  if((wd[i_500] - wd[i_850]) < 0) sh_term=0;
	  if(ws[i_850] < 15 || ws[i_500] < 15) sh_term=0;
	  if(sh_term < 0) sh_term=0;
	  double tt = totalTotals() - 49;
	  if(tt < 0) tt = 0;
	  double dpC = dewpt[i_850]-273.15;
	  if(dpC < 0) dpC = 0;
	  sweat = (int)Math.round(12*dpC + 20*tt + 2*ws[i_850] + ws[i_500] +
				  sh_term);
	}
      }
    return sweat;
}

	
public int totalTotals() {
    int tt = Sounding.MISSING;
    if(no_dewpoint || n_levels <= 0) {
      return Sounding.MISSING;
    }

    if (i_850 >=0 && i_500 >= 0) {
      tt=(int)Math.round(temp[i_850] + dewpt[i_850] - 2*temp[i_500]);
    }
    return tt;
  }

  /** the Lifted Index.  Define boundary as 100mb thick for now
  *
  */
public int liftedIndex() {
    if(no_dewpoint || n_levels <= 0 ||
       i_500 == -1) {
      return Sounding.MISSING;
    }
    int i;
    double t_sum, td_sum;
    double p_weight, weight_sum;
    double t_top, td_top;
    p_boundary = pres[0] - 100.0;
    p_parcel = pres[0]-50.0;
    t_sum = 0;
    td_sum = 0;
    weight_sum = 0;

    for (i=1; i<n_levels; i++) {
      if (pres[i] > p_boundary) {
	p_weight = (pres[i-1] - pres[i]);
	t_sum += (temp[i-1] + temp[i])*p_weight/2.0;
	td_sum += (dewpt[i-1] + dewpt[i])*p_weight/2.0;
	weight_sum += p_weight;

      } else {
	break;
      }
    }
    // at this point, (i-1) -> (i) contains p_boundary;
    //  first interpolate t,td
    t_top = temp[i] +
      (temp[i-1]-temp[i]) * (p_boundary - pres[i]) / 
	                    (pres[i-1] - pres[i]);
    td_top = dewpt[i] +
      (dewpt[i-1]-dewpt[i]) * (p_boundary - pres[i]) / 
			      (pres[i-1] - pres[i]);

    // now compute remaining averages

    p_weight = (pres[i-1] - p_boundary);
    t_sum += (temp[i-1] + t_top)*p_weight/2.0;
    td_sum += (dewpt[i-1] + td_top)*p_weight/2.0;
    weight_sum += p_weight;

    // Now define the parcel:

    t_parcel = t_sum/weight_sum;
    td_parcel = td_sum/weight_sum;
    presAtLCL = (int)Math.round(pressureAtLCL(t_parcel, td_parcel, pres[0]));
    
    Parcel_theta_e = parcelThetaE( t_parcel, td_parcel, p_parcel);
    int iii= (int)Math.round(temp[i_500] -
		           tempAlongSatAdiabat(Parcel_theta_e, 500.0) );
    return iii;
  }

/** Showalter index.  Recent paper said it was "better"
  * than LI?  
  */
public int showalter() {
    int i_850, i_500;
    i_850 = -1; i_500 = -1;
    double theta_e;
    if(no_dewpoint || n_levels <= 0) {
      return Sounding.MISSING;
    }

    for (int i=0; i<n_levels; i++) {
      if (Math.round(pres[i]) == 850) i_850 = i;
      if (Math.round(pres[i]) == 500) i_500 = i;
      if (i_850 >=0 && i_500 >= 0) {
        
	theta_e = parcelThetaE( temp[i_850], dewpt[i_850], 850.0);
	int iii = (int) (temp[i_500] - tempAlongSatAdiabat(theta_e, 500.0)); 
	return iii; 
      }
    }
    return Sounding.MISSING;
  }

  /** pressure at the LCL
  */
public int presLCL() {
    if(no_dewpoint || n_levels <= 0) {
      return Sounding.MISSING;
    }
    int v = liftedIndex();
    return presAtLCL;
  }

  /** pressure at the level of free convection
  *
  */
public int presLFC() {
    if(no_dewpoint || n_levels <= 0) {
      return Sounding.MISSING;
    }
    double the[] = new double[n_levels];
    double tdiff[] = new double[n_levels];
    int levelMaxTheta_e= 0;
    int indexPLFC = 0;
    int indexEP = 0;

    Debug.println("n_levels is "+n_levels);
    for (int i=0; i<n_levels; i++) {
      the[i] = parcelThetaE(temp[i], dewpt[i], pres[i]);
      tdiff[i] = tempAlongSatAdiabat(Parcel_theta_e, pres[i] ) -
	temp[i];
      if (pres[i] > 500. && the[i] > the[levelMaxTheta_e] )
	levelMaxTheta_e = i;
    }

    for (int i=1; i<n_levels; i++) {
      if (tdiff[i] > 0.0 && indexPLFC == 0 && i >
	  levelMaxTheta_e) {
	indexPLFC = i;
      }
      if (tdiff[i] < 0 && indexPLFC != 0 && indexEP == 0) {
	indexEP = i;
      }
    }

    if (indexEP != 0) {
      presEPL =  (int)  (pres[indexEP-1] + 
	  ( pres[indexEP] - pres[indexEP - 1] ) *
	  ( 0. - tdiff[indexEP-1] ) / 
	  ( tdiff[indexEP] - tdiff[indexEP-1]));
    } else {
      presEPL = Sounding.MISSING;
    }

    if (indexPLFC != 0) {
      return (int)  (pres[indexPLFC-1] + 
	( pres[indexPLFC] - pres[indexPLFC - 1] ) *
	( 0. - tdiff[indexPLFC-1] ) / 
	( tdiff[indexPLFC] - tdiff[indexPLFC-1]));
    } else {
      return Sounding.MISSING;
    }

  }

  /**  equillibrium pressure level
  *
  */
public int presEP() {
    if(no_dewpoint || n_levels <= 0) {
      return Sounding.MISSING;
    }
    int v = presLFC();
    return presEPL;
  }

  /** K index.  interpolate to missng levels later
  *
  */
public int kIndex() {
    if(no_dewpoint || n_levels <= 0) {
      return Sounding.MISSING;
    }
  if (i_850 >=0 && i_700 > 0 && i_500 > 0) {
    return (int) ( (temp[i_850] + dewpt[i_850]) - temp[i_500]
		  - (temp[i_700] - dewpt[i_700]) - 273.15 );
  }
  return Sounding.MISSING;
}



  /** compute heights
  *
  */
public double[] getHeights(double sfcHeight) {
    double tvLower, tvUpper;
    double[] heights = new double[n_levels];
    heights[0] = sfcHeight;
    tvLower = virtualTemperature(temp[0], dewpt[0], pres[0]);
    for (int i=1; i<n_levels; i++) {
      tvUpper = virtualTemperature(temp[i], dewpt[i], pres[i]);
      heights[i] = heights[i-1] + (287.04 / 9.8) *
	(tvLower + tvUpper) * .5 * Math.log(pres[i-1]/pres[i]);
    }
    return heights;
  }

/** Virtual Temperature
  *
  */
public static double virtualTemperature(double t, double td, double p) {
    return ( t * (1.0 + .000609*mixingRatio(td, p)) );
  }

/** saturation vapor pressure over water
 * expects t in Kelvins
  *
  */
public static double satVapPres(double t) {
  double coef[]={6.1104546,0.4442351,1.4302099e-2, 2.6454708e-4,
            3.0357098e-6, 2.0972268e-8, 6.0487594e-11,-1.469687e-13};
  int inx=0;
  // sat vap pressures every 5C from -50 to -200
  double escold[] = {
    0.648554685769663908E-01, 0.378319512256073479E-01,
    0.222444934288790197E-01, 0.131828928424683120E-01,
    0.787402077141244848E-02, 0.473973049488473318E-02,
    0.287512035504357928E-02, 0.175743037675810294E-02,
    0.108241739518850975E-02, 0.671708939185605941E-03,
    0.419964702632039404E-03, 0.264524363863469876E-03,
    0.167847963736813220E-03, 0.107285397631620379E-03,
    0.690742634496135612E-04, 0.447940489768084267E-04,
    0.292570419563937303E-04, 0.192452912634994161E-04,
    0.127491372410747951E-04, 0.850507010275505138E-05,
    0.571340025334971129E-05, 0.386465029673876238E-05,
    0.263210971965005286E-05, 0.180491072930570428E-05,
    0.124607850555816049E-05, 0.866070571346870824E-06,
    0.605982217668895538E-06, 0.426821197943242768E-06,
    0.302616508514379476E-06, 0.215963854234913987E-06,
    0.155128954578336869E-06};

  double temp = t - 273.15;
  double retval = 0;
  try {
  if (temp > -50.) {
    retval = ( coef[0] + temp*(coef[1] + temp*(coef[2] + temp*(coef[3] +
    temp*(coef[4] + temp*(coef[5] + temp*(coef[6] + temp*coef[7])))))));

  } else {
     double tt = (-temp - 50.)/5.;
     inx = (int) tt;
     if (inx < escold.length-1) {
       retval = escold[inx] + (tt % 1.)*(escold[inx+1]-escold[inx]);
     } else {
       retval = 1e-7;
     }
  }
  } catch (Exception e) {
    Debug.println("caught exception: "+e);
    retval = 1e-7;
  }
  return retval;
}

/** mixing ratio
  *
  */
public static double mixingRatio(double t, double p) {
    double e = satVapPres(t);
    return ( 621.97*e/(p - e) );
  }

  /** temperature at LCL (old SELS method)
  *
  */
public static double tempAtLCL(double t, double td) {
    return (td - (.001296*td - .15772)*(t-td) );
  }

  /** define the parcel's theta-E.  Pressure should be Station
   * Pressure!
   */
public static double parcelThetaE(double t, double td, double p) {
    double theta = t * Math.pow ( 1000.0/p, .286);
    double ddd;
    try {
      ddd = Math.exp(2481.9e-3*mixingRatio(td,p)/tempAtLCL(t, td));
    } catch (Exception e) {
      Debug.println("Exception in parcelThetaE: "+e);
      ddd=0;
    }
    return (theta * ddd);
  }

  /** pressure at the LCL
  *
  */
public static double pressureAtLCL(double t, double td, double p) {
    double theta = t * Math.pow( 1000.0/p, .286);
    return (1000./ Math.pow( theta/tempAtLCL(t, td), 3.5) );
  }

/** compute temperature along Pseudo Adiabats.  This iterates
  * until it converges....
  *
  */
public static double tempAlongSatAdiabat(double thetaE, double p) {
    double s=0;
    double th=0;

    double pcon = Math.pow( 1000.0/p, .286);
    double t = 273.0;
    double delta = 20.;
    int i=0;
    while (Math.abs(delta) > .1 && i < 100) {
      i++;
      s = mixingRatio(t, p);
      th = t * pcon * Math.exp(2.5*s/t);
      if ( (th-thetaE)*delta > 0.0) delta = -.5 * delta;
      t = t + delta;
    }
    return (t);
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
    } else if(result > 359) {
      result -= 360;
    }
  }
  return (result);
}

}
