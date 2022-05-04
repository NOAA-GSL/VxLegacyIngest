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

/** Stores a level for a sounding
*/
public class SoundingLevel {
    public int n_level;    //index of this level in a sounding
    public float p;       //in millibars
    public float z;       //in meters
    public float z_gps;    //gps altitude in meters
    public float t;       //in Centigrade
    public float dp;      //in Centigrade
    public float dpUnc;   // dewpoint uncertainty in Centigrade
    public float wd;      //in degrees true
    public float ws;      //in knots
    public float bearing; //from release point or airport
    public float range;   //ditto, in nautical miles
    public UTCDate date;
    public int data_descriptor; // A/C quality control flag

public SoundingLevel(int _n_level,float _p, float _z,
		     float _t, float _dp,
                     float _wd, float _ws) {
    n_level=_n_level;
    p=_p;
    z=_z;
    t=_t;
    dp=_dp;
    // keep various folks happy: don't allow dewpoint to exceed temperature!
    if(dp != Sounding.MISSING && dp > t) {
      dp = t;
    }
    wd=_wd;
    if(wd == 360) wd = 0;
    ws=_ws;
    bearing=Sounding.MISSING;
    range=Sounding.MISSING;
    dpUnc = Sounding.MISSING;
    z_gps = Sounding.MISSING;
    date=null;
}

public SoundingLevel(int n_level,float p, float z, float z_gps,
		     float t,
		     float dp, float dpUnc,
                     float wd, float ws, float bearing, float range,
		     UTCDate date, int data_descriptor) {
   this(n_level,p,z,t,dp,wd,ws);
   this.z_gps = z_gps;
   this.dpUnc = dpUnc;
   this.bearing=bearing;
   this.range=range;
   this.date = date;
   this.data_descriptor=data_descriptor;
}

public String toString() {
    String zs = MyUtil.goodRoundString(z/0.3048,-1000,
                                       1.e10,"------",0,6);
    String baro = "  ";
    if(data_descriptor > 3) {
      baro = "* ";
    }
    String ps = MyUtil.goodRoundString(p,0,1200,"----",0,4)+" ";
    String ts = MyUtil.goodRoundString(t,-200,200,"----",1,5)+"/";
    String dps = MyUtil.goodRoundString(dp,-200,200,"-----",1,-5)+"    ";
    String wds = MyUtil.goodRoundString(wd,0,359,"---",0,3)+"\u00b0/";
    String wss = MyUtil.goodRoundString(ws,0,300,"---",0,-3);
    String bs="";
    String rs="";
    if(bearing != Sounding.MISSING) {
        bs = "  "+MyUtil.goodRoundString(bearing,0,360,"---",0,3)+"\u00b0/";
        rs = MyUtil.goodRoundString(range,0,1.e10,"---",0,-3);
    }
    String time_s="";
    if(date != null) {
        double tt = MyUtil.atof(date.getHHMM());
        time_s = "   "+MyUtil.goodRoundString(tt,0,2359,"",0,-4);
    }
    return zs + baro+ ps + ts + dps + // "=/-"+dpUnc+"  " +
      wds + wss + time_s + bs + rs;
}

}
