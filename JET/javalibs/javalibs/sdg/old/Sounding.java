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
import java.awt.*;
import java.util.*;
import java.io.*;

/** Stores a sounding
 *  11-6-00 makeMands updated to keep the level number of each
 *          SoundingLevel current
*/
public class Sounding {
  //class variables
  public static int MISSING = 99999;   //missing flag
  public static float INF_DP_UNCERTAINTY = 999.f;
  
  public static int n_soundings = 0;   //number of soundings
  static int n_soundings_to_plot=0;     //number of soundings to plot
  static int soundings_to_plot[] = new int[100];

  //instance variables
  public int n_sounding;               //index of this sounding
  public String type;	 // "A" for analysis, "F" for forecast,"Up", or "Dn"
  public int fcst_len;           //forecast length in hours
  public UTCDate ground_date;    //date of ascent or descent
  public UTCDate furthest_date;  //date of furthest point
  public float station_lat;
  public float station_lon;
  public float station_elev;    // elevation in feet
  public String station_name;
  public String station_description;
  public String instrument;
  public float max_bearing=0; //bearing and range of furthest point
  public float max_range=0;   //in nautical miles
  public float grid_bearing=0; // bearing from airport TO grid point
  public float grid_range=-9999.f;   // range from airport TO grid point
  public float CAPE,CIn,Helic,PW;
  public float TotalTotals,KIndex,LiftedIndex,Showalter,Sweat,ParcelLCL;
  public float LFC,EquibPressureLevel;
  public int n_levels;
  public Vector level;
  public boolean mands_made=false;
  public Stability sta;
  public double iCIn;			// CIN and CAPE from interactive parcel
  public double iCAPE;			// (see classes SkewTPlot and Stability)
  public String model = "";

public Sounding() {
    //a dummy so we can easily subclass this
}

public Sounding(String _type, int _fcst_len, UTCDate _date,
                float _lat, float _lon, String _name) {
   type=_type;
   fcst_len=_fcst_len;
   ground_date = _date;
   furthest_date=_date;
   station_lat = _lat;
   station_lon = _lon;
   station_name = _name;
   station_description = null;
   station_elev = MISSING;
   CAPE=MISSING;
   CIn=MISSING;
   Helic=MISSING;
   PW=MISSING;
   TotalTotals=MISSING;
   KIndex=MISSING;
   LiftedIndex=MISSING;
   Showalter=MISSING;
   Sweat=MISSING;
   ParcelLCL=MISSING;
   LFC=MISSING;
   EquibPressureLevel=MISSING;
   iCIn = MISSING;
   iCAPE = MISSING;
   n_levels = 0;
   level = new Vector(50,50);
}

public Sounding(String type, int fcst_len, UTCDate date,
                float lat, float lon, String name, String instrument,
                float CAPE,float CIn,float Helic,float PW) {
  this(type,fcst_len,date,lat,lon,name);
  this.instrument=instrument;
  this.CAPE = CAPE;
  this.CIn = CIn;
  this.Helic = Helic;
  if(Helic < -99998) {
    this.Helic = MISSING;
  }
  this.PW = PW;
}

public Sounding(String data_source,
		String type, int fcst_len, UTCDate date,
                float lat, float lon, String name, String instrument,
                float CAPE,float CIn,float Helic,float PW,
		float grid_bearing,float grid_range) {
  this(type,fcst_len,date,lat,lon,name,instrument,CAPE,CIn,Helic,PW);
  this.model = data_source;
  this.grid_bearing = grid_bearing;
  this.grid_range = grid_range;
}

public boolean addLevel(float p, float z, float z_gps, int ice,
			float t,
			float dp, float dpUnc,
			float wd, float ws,
			float bearing,float range,UTCDate date,
			int data_descriptor) {
   //looks like sometime we can have two 'levels' with the same pressure,
   //some with wind missing, some with temp missing.
   //account for this
   boolean added_level = false;
   boolean same_level = false;
   boolean added_missing=false;
   if(n_levels > 0) {
   SoundingLevel last_lev = (SoundingLevel)level.elementAt(n_levels-1);
   if(last_lev.p == p) {
    //Debug.println("same level!");
    same_level=true;
      //no need to add another level,  just fill in missing values
      if(last_lev.z == Sounding.MISSING) {
        last_lev.z = z;
        added_missing=true;
      }
      if(last_lev.t == Sounding.MISSING) {
        last_lev.t = t;
        added_missing=true;
      }
      if(last_lev.dp == Sounding.MISSING) {
        last_lev.dp = dp;
        added_missing=true;
      }
      if(last_lev.wd == Sounding.MISSING) {
        last_lev.wd = wd;
        added_missing=true;
      }
      if(last_lev.ws == Sounding.MISSING) {
        last_lev.ws = ws;
        added_missing=true;
      }
   }
   }
   if(! same_level || ! added_missing) {
    //Debug.println("New Level!, or another good ob at the same level");
     level.addElement(new SoundingLevel(n_levels,p,z,z_gps,ice,
					 t,dp,dpUnc,wd,ws,
					 bearing,range,date,
					 data_descriptor));
      added_level=true;
      n_levels++;
   }
   return added_level;
}

public void calcParameters() {
  sta = new Stability(this);
  TotalTotals = sta.totalTotals();
  LiftedIndex = sta.liftedIndex();
  KIndex = sta.kIndex();
  Showalter = sta.showalter();
  Sweat = sta.sweat();
  ParcelLCL = sta.presLCL();
  LFC = sta.presLFC();
  EquibPressureLevel = sta.presEP();
}
  
/* generate mandatory levels, if we have not done so already */
public void makeMands() {
  SoundingLevel lev,last_lev;
  float mand_p,mand_z,mand_z_gps,mand_t,mand_dp,mand_wd,mand_ws,fact;
  int j;
  int this_mand=0;
  if(mands_made) {
    return;
  }
  float[] mand_level =
    {1000.f,925.f,850.f,700.f,500.f,400.f,300.f,250.f,150.f,100.f};
  int mand_levels = mand_level.length;

  //put in any mand levels below the first
  /*lev = (SoundingLevel)level.elementAt(0);
  boolean done=false;
  int j_mand=0;
  while(j_mand < mand_levels &&
	mand_level[j_mand] > lev.p) {
    this_mand=j_mand;
    level.insertElementAt(
      new SoundingLevel(this_mand,mand_level[this_mand],
			MISSING,MISSING,MISSING,MISSING,MISSING),
      this_mand);
    Debug.println("Inserting empty mand level "+mand_level[this_mand]+" at "+
		  this_mand);
    j_mand++;
  }*/

  // interpolate any other mand levels
  for (int i=1; i<level.size(); i++) {
    last_lev = (SoundingLevel)level.elementAt(i-1);
    lev = (SoundingLevel)level.elementAt(i);
    //see if these levels bracket a mand level
    for (j=this_mand+1;j<mand_levels;j++) {
      if(last_lev.p > mand_level[j] &&
	 lev.p < mand_level[j]) {
	this_mand=j;
	//create a new interpolated mand level
	fact=(float)
	  ((Math.log(last_lev.p)-Math.log(mand_level[this_mand])) /
	  (Math.log(last_lev.p)-Math.log(lev.p)));
	mand_z=Stability.my_interp(fact,last_lev.z,lev.z);
	mand_z_gps =
	  Stability.my_interp(fact,last_lev.z_gps,lev.z_gps);
	mand_t=Stability.my_interp(fact,last_lev.t,lev.t);
	mand_dp=Stability.my_interp(fact,last_lev.dp,lev.dp);
	mand_ws=Stability.my_interp(fact,last_lev.ws,lev.ws);
	mand_wd=Stability.my_dir_interp(fact,last_lev.wd,lev.wd);
	level.insertElementAt(
	  new SoundingLevel(i,mand_level[this_mand],
			    mand_z,mand_z_gps,-1,
			    mand_t,
			    mand_dp,last_lev.dpUnc,
			    mand_wd,mand_ws,MISSING,MISSING,null,
			    last_lev.data_descriptor),
	  i);
	Debug.println("Interpolating mand level "+mand_level[this_mand]+
		      "between "+last_lev.p+" and "+lev.p+"\n\twith temps "+
		      last_lev.t+" and "+lev.t+" at "+
		  i);

	i++;			// shift the index to follow the vector
      } // end insert new mand level section
    } //end over loop over mand levels
  } //end loop over sounding levels
  // update the level number information in each level
  // the addition of mand levels invalidates lev.n_level, so we must fix it
  Enumeration e = level.elements();
  n_levels=0;
  while(e.hasMoreElements()) {
    lev = (SoundingLevel) e.nextElement();
    lev.n_level = n_levels;
    n_levels++;
  }
  mands_made=true;
}


public String toString() {
    return getShortTitle()+" "+ground_date.getHHMM()+" "+
      ground_date.getDDMMYY();
}

public String getModelString() {
  return model+" "+toString();
}
  
public String getShortTitle() {
    if(fcst_len != 0) {
        return(station_name+"("+type+fcst_len+")");
    } else {
        return(station_name+"("+type+")");
    }
}

public String[] getLongTitle() {
    String[] result = new String[1];
    String long_type=model;
    if(type.toLowerCase().startsWith("a")) {
      long_type += " Analysis";
    } else if(type.toLowerCase().startsWith("f")) {
       long_type += " "+fcst_len+"h Forecast";
    } else if(type.startsWith("R")) {
        long_type = "RAOB";
    } else if(type.startsWith("P")) {
        long_type = "Profiler";
    } else if(type.equals("Up")) {
      long_type="Ascent ("+instrument+")";
    } else if(type.equals("Dn")) {
      long_type="Descent ("+instrument+")";
    }
    result[0]=long_type+", "+ground_date+" (";
    if(grid_range != MISSING) {
      int gb = (int)grid_bearing;
      result[0] += grid_range+"nm/"+gb+"\u00b0 from ";
    }
    result[0] += station_name+")";
    if(station_description != null) {
      result[0] += " ("+station_description+")";
    }
    return result;
}


public String getFullText() {
  //check that first level has bearing/range
  String out="";
  String br_title1="";
  String br_title2="";
  if(n_levels > 0) {
    SoundingLevel lev = (SoundingLevel)level.elementAt(0);
    if(lev.bearing != MISSING) {
      br_title1 = " Bng/Rng";
      br_title2 = "    (nm)";
    }
    String tm_title1="";
    String tm_title2="";
    if(lev.date != null) {
      tm_title1 = "Time";
      tm_title2 = "(UTC)";
    }
    String agl_title1="";
    String agl_title2="";
    if(lev.z_gps < Sounding.MISSING - 1 &&
       station_elev < Sounding.MISSING - 1) {
      agl_title1 = "   AGL";
      agl_title2 = "  (ft)";
    }
    String[] lt = getLongTitle();
    out = toString()+"\n"+lt[0];
    if(lt.length > 1) {
      out += "\n"+lt[1]+"\n\n";
    } else {
      out += "\n\n"; //    \u00b0
    }
    boolean thermo = false;
    if(CAPE != MISSING) {
      out += " CAPE = "+CAPE+" J/Kg";
      thermo = true;
    }
    if(CIn != MISSING) {
      out += ", CIn = "+CIn+" J/Kg";
      thermo = true;
    }
    if(PW != MISSING) {
      out += ", PW = "+PW+" Kg/m^2";
      thermo = true;
    }
    if(Helic != MISSING) {
      out += ", Helic = "+Helic+" m^2/s^2";
      thermo = true;
    }
    if(thermo) {
      out += "\n";
      thermo=false;
    }
    if(TotalTotals != MISSING) {
      out += " TT = "+TotalTotals;
      thermo = true;
    }
    if(KIndex != MISSING) {
      out += " KI = "+KIndex;
      thermo = true;
    }
    if(LiftedIndex != MISSING) {
      out += " LI = "+LiftedIndex;
      thermo = true;
    }
    if(Showalter != MISSING) {
      out += " SI = "+Showalter;
      thermo = true;
    }
    if(Sweat != MISSING) {
      out += " SW = "+Sweat;
      thermo = true;
    }
    if(thermo) {
      out += "\n";
      thermo=false;
    }
    if(ParcelLCL != MISSING) {
      out += " LCL = "+ParcelLCL;
      thermo = true;
    }
    if(LFC != MISSING) {
      out += " LFC = "+LFC;
      thermo = true;
    }
    if(EquibPressureLevel != MISSING) {
      out += " EL = "+EquibPressureLevel;
      thermo = true;
    }
    if(thermo) {
      out += "\n\n";
    }
    
    //column headers
    out += " P_alt    mb     t/td    w_dir/w_spd   "+tm_title1+"  "+br_title1 + agl_title1+"\n"+
      "  (ft)           (\u00b0C)          (kts)  "+tm_title2+"  "+br_title2 + agl_title2+"\n\n";
    
    boolean baro_altitudes=false;
    for(int i=0;i<n_levels;i++) {
      lev = (SoundingLevel)level.elementAt(i);
      out += ""+lev;
      if(lev.z_gps < Sounding.MISSING - 1 &&
	 station_elev < Sounding.MISSING - 1 &&
	 lev.bearing != Sounding.MISSING) {
	out += " "+ MyUtil.goodRoundString(lev.z_gps/0.3048 - station_elev,
					   -1.e10,1.e10,"",0,5);
      }
      if(lev.ice > 0) {
	out += " ice";
      }

      out += "\n";
      if(lev.data_descriptor > 3) {
	baro_altitudes=true;
      }
    }
    if(baro_altitudes) {
      out += "* altitude was referenced to the (unknown) "+
	"local barometric pressure\n";
    }
  }
  return out;
}


/*public void print_levels() {
    for(int i=0;i<n_levels;i++) {
        SoundingLevel lev = (SoundingLevel)level.elementAt(i);
        Debug.println(lev.p+", "+lev.z);
    }
}*/


  //used for calculating between pressure <-> altitude
  //constants taken from 1976 US Standard Atmosphere
  static double g= 9.80665; //(m s^-2) accl. of gravity
  //1976 Std Atmosphere height limits (geopotential meters)
  static double[] std_h_low = {0,11000.,20000.,32000.,47000};
  //lapse rates starting at 0,11,20,32 Km (Km/m)
  static double[] gam = {-.0065,0,.001,.0028};
  //temperature of 1976 Std Atmos at 0,11,20,32 geopotential Km (Kelvin)
  static double[] T_low = {288.15,216.65,216.65,228.65};
  //pressure of 1976 Std Atmos at 0,11,20,32 geopotential Km (mb)
  static double[] p_low = {1013.25,226.32,54.748,8.6801};
  //gas const. for dry air (MKS) ( = 8314.32/28.9644, 1976 Std Atmos)
  static double r=287.05307;
  //radius of earth (meters)
  static double r_earth = 6356766.0;

public static float getStdPressure(float altitude) {
  return (float) getStdPressure( (double) altitude);
}


public static double getStdPressure(double altitude) {
  //input: altitude in ft.
  //returns standard pressure in mb
  
  //find appropriate lapse rate
  double z = altitude*0.3048;  //z is altitude in meters
  double h = r_earth*z/(r_earth + z); //h is geopotential height
  //Debug.println("into getStdPressure with "+z);
  int level=-1;
  for(int i=1;i<std_h_low.length;i++) {
    if(h < std_h_low[i]) {
      level = i-1;
      break;
    }
  }
  if(level == -1) {
    //Debug.println("returning early");
    return Sounding.MISSING;
  }
  double p0 = p_low[level];
  double T0 = T_low[level];
  double p;
  double T;
  if(gam[level] == 0) {
    //isothermal atmosphere
    T = T_low[level];
    p = p0*Math.exp(-(h-std_h_low[level])*g/(r*T));
  } else {
    double alfa = -g/(r*gam[level]);
    T=T0 + gam[level]*(h-std_h_low[level]);
    p=p0*Math.pow((T/T0),alfa);
  }
  //Debug.println("t is "+T+", p is "+p+", z is "+z+", h is "+h);
  return p;
}
  
public static double getAltitude(double p) {
  //takes pressure in mb
  //returns altitude in feet
  //find appropriate lapse rate
  int level=-1;
  for(int i=1;i<std_h_low.length;i++) {
    if(p > p_low[i]) {
      level = i-1;
      break;
    }
  }
  if(level == -1) {
    //Debug.println("returning early");
    return Sounding.MISSING;
  }
  //level now gives the appropriate section 
  double p0 = p_low[level];
  double T0 = T_low[level];
  double a1 = Math.log(p/p0);
  double h=Sounding.MISSING;
  if(gam[level]==0) {
    h = std_h_low[level] - (r*T0/g)*a1;
  } else {
    double alfa = -g/(r*gam[level]);
    double a2 = a1/alfa;
    h = std_h_low[level] + (T0/gam[level])*(Math.exp(a2) -1);
  }
  double z = Sounding.MISSING;
  if(h != Sounding.MISSING) {
    z = r_earth*h/(r_earth - h);
  }
  return z/0.3048;
}
  
} //end of class Sounding
