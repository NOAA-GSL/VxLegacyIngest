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
import java.net.*;
import java.io.*;
import java.util.*;

/**
 * Change history:
 * 11-May-04 - Do not add a level if t,dp,wd,ws,bearing,range are all
 *             missing.  This done to avoid below-surface levels on
 *             RAOBs, which were screwing up finding the right level
 *             to show near the cursor.
 *
 */
public class SoundingLoader extends Thread {
  static SoundingLoader current_loader=null;
  SoundingPanel p;

public SoundingLoader(SoundingPanel p) {
  this.p = p;
  current_loader = this;
  this.start();
}

static public void stop_loader() {
  if(current_loader != null && current_loader.isAlive()) {
    SoundingPanel.loading_soundings=false;
    //current_loader.stop();  // DEPRECATED
    current_loader = null;
  }
}
  
public void run() {
  setPriority(Thread.MIN_PRIORITY);
    SoundingPanel.loading_soundings=true;
    p.displayArea.repaint();
    String airport = p.desired_airport;
    String line="";
  String sounding_type=null;
  String short_type="";
  float range=Sounding.MISSING;
  float bearing=Sounding.MISSING;
  int hhmm,sec_of_day,delta_secs;
  int prev_sec_of_day=0;
  String instrument=null;
    Sounding s = null;
    int sounding_index=0;
    long t1 = System.currentTimeMillis();
    boolean bad_sounding=false;
    boolean bad_airport=false;
    boolean bad_time=false;
    boolean bad_location=false;
    boolean bad_raob=false;
    boolean bad_format=false;
    float CAPE=Sounding.MISSING;
    float CIn=Sounding.MISSING;
    float Helic=Sounding.MISSING;
    float PW=Sounding.MISSING;
    InputStream fin=null;
    BufferedInputStream bfin=null;
    DataInputStream in=null;
    boolean model = false;		// true for model soundings

    try {
      //get
      String access_file="";
      String enc_airport = URLEncoder.encode(airport);
      String args = "airport="+enc_airport+"&data_source="+p.data_source+
	"&startSecs="+p.startSecs+"&endSecs="+p.endSecs;
      if(p.latest) {
	// "latest" data is desired.
	double n_hrs = (p.endSecs - p.startSecs)/3600.;
	args = "airport="+enc_airport+"&start=latest&n_hrs="+n_hrs+
	  "&data_source="+p.data_source;
      }
      access_file = "soundings/reply-setup.cgi?"+args;
      URL soundingURL = new URL(p.code_base,access_file);
      URLConnection urlc = soundingURL.openConnection();
      urlc.setUseCaches(false);
      urlc.setAllowUserInteraction(true);
      Debug.println("Observations URL = "+soundingURL);
      urlc.connect();
      String key = urlc.getHeaderFieldKey(0);
      int i2=0;
      while(key != null) {
	String val = urlc.getHeaderField(key);
	Debug.println(i2+" "+key+" => "+val);
	key = urlc.getHeaderFieldKey(++i2);
      }
      fin = urlc.getInputStream();
      bfin = new BufferedInputStream(fin,4096);
      in = new DataInputStream(bfin);
      //Debug.println("Set up data input stream for obs");

      int i;
      String dum;
      int line_type=0;		// line_type indicates kind of level
      // see http://www-frd.fsl.noaa.gov/soundings/java/beta/raob_format.html
      UTCDate sounding_date=null;
      UTCDate level_date=null;
      float lat=0;
      float lon=0;
      float elev=0;
      String flag = "";
      int fcst_len=0;
      boolean done=false;
      boolean some_levels=false;
      while (! done) {   //loop over soundings
	i=-2;  //set up to read sounding
	Debug.println("looking for sounding...");
	sounding_date=null;
	instrument=null;
	range =Sounding.MISSING;
	while(true) {
	  line=in.readLine();
	  Debug.println(i+": "+line);
	  if(line == null) {
	    Debug.println("End of file");
	    done=true;
	    break;
	  }
	  if(line.trim().equals("")) {
	    Debug.println("blank line!");
	    if(i==-2) {
	        done=true;
	    }
	    break;
	  }
	  if(line.indexOf("ERROR") >= 0) {
	    break;
	  }
	  i++;
	  StringTokenizer items = new StringTokenizer(line," ");
	  if(i==-1) {
	    Debug.println(line);
	    sounding_type =  items.nextToken();
	    some_levels=false;
	    Debug.println("Sounding type is "+sounding_type);
	    if( sounding_type.startsWith("airport")) {
	      Debug.println("Bad airport");
	      bad_airport = true;
	      bad_sounding=true;
	      Sounding.n_soundings_to_plot=0;
	      break;
	    } else if(sounding_type.startsWith("time") ||
		      line.indexOf("for this time") != -1) {
	      Debug.println("Bad time");
	      bad_time = true;
	      bad_sounding=true;
	      Sounding.n_soundings_to_plot=0;
	      break;
	    } else if(sounding_type.startsWith("location")) {
	      Debug.println("Bad location");
	      bad_location = true;
	      bad_sounding=true;
	      Sounding.n_soundings_to_plot=0;
	      break;
	    } else if(sounding_type.indexOf("<body>") != -1) {
	      Debug.println("Strange bad sounding");
	      bad_raob=true;
	      bad_sounding=true;
	      Sounding.n_soundings_to_plot=0;
	      break;
	    } else if(sounding_type.equals("A:")) {
	      //an ACARS sounding. lotsa info on first line
	      items.nextToken(); // airport name
	      items.nextToken(); // "AC#"
	      instrument = "AC# "+items.nextToken();
	      items.nextToken(); // "U/D"
	      if(items.nextToken().equals("1")) {
		short_type="Up";
	      } else {
		short_type="Dn";
	      }
	      // read a buncha items
	      while(! items.nextToken().equals("Secs")) {}
	      sounding_date = new UTCDate(MyUtil.atoi(items.nextToken()));
	      level_date = sounding_date;
	      //save the start seconds for use
	      //when we look at times at each lev
	      prev_sec_of_day = sounding_date.getSecs();
	    } else {
	      // not an ACARS sounding
	      String maybe = items.nextToken();
	      if(maybe.equalsIgnoreCase("sounding")) {
	        if(sounding_type.equals("PROF")) {
	            short_type="P";  //a profiler sounding
		} else if(sounding_type.equals("RADIO")) {
		  short_type = "r";
	        } else {
                short_type="R";
	      }
		fcst_len=0;
	      } else if(maybe.equals("analysis")) {
                short_type="A";
                fcst_len=0;
	      } else {
                short_type="F";
                fcst_len = Integer.parseInt(maybe);
	      }
	      // get distance to grid point, if available
	      while(items.hasMoreTokens()) {
		String it = items.nextToken();
		model = false;
		if(it.equals("point")) {
		  model = true;
		  range = MyUtil.atof(items.nextToken());
		  items.nextToken(); // 'nm'
		  items.nextToken(); // '/'
		  bearing = MyUtil.atof(items.nextToken());
		  break;
		}
	      }
	    }
	 }  else if(i==0) {
	    flag =  items.nextToken(); //the word 'MAPS' or 'PROF' or '254'
	    Debug.println("flag = "+flag);
	    int hour = Integer.parseInt(items.nextToken());
	    int day = Integer.parseInt(items.nextToken());
	    String month_name = items.nextToken();
	    int month = UTCDate.get_month_num(month_name);
	    int year = Integer.parseInt(items.nextToken());
	    int min = 0;
	    Debug.println("Hour is "+hour+", day is "+day+" month is "+month);
	    if(items.hasMoreTokens()) {
	      min = Integer.parseInt(items.nextToken());
	    }
	    if(sounding_date == null) {
	      //for AC soundings we already have an accurate date
	      sounding_date = new UTCDate(year,month,day,hour,min,0);
	    }
	    // for models, we also have
	    // some thermodynamic info
	    if(model) {
	      line = in.readLine();
	      items = new StringTokenizer(line," ");
	      dum = items.nextToken(); //the word CAPE
	      CAPE = MyUtil.atof(items.nextToken());
	      dum = items.nextToken(); //the word CIn
	      CIn = MyUtil.atof(items.nextToken());
	      dum = items.nextToken(); //the word Helic
	      Helic = MyUtil.atof(items.nextToken());
	      dum = items.nextToken();  //the word PW
	      PW = MyUtil.atof(items.nextToken());
	      Debug.println("CAPE = "+CAPE+", CIn = "+CIn+", Helic = "+Helic);
	    }
	  } else if (i == 1) {
	    dum = items.nextToken();  //'1'
	    dum = items.nextToken();  // don't know
	    dum = items.nextToken();  // don't know
	    int NS = 1;		// Northern of Southern hemisphere
	    if(flag.equals("RAOB")) {
	      String latlon = items.nextToken();
	      Debug.println("latlon is "+latlon+", of length"+
			    latlon.length());
	      int break_index = latlon.indexOf("N");
	      if(break_index != -1) {
		// Northern hemisphere
	      } else {
		break_index = latlon.indexOf("S");
		NS = -1;
	      }
	      if(break_index > 0) {
		lat = MyUtil.atof(latlon.substring(0,break_index))*NS;
		// lon may be in the next token, depending on whether
		// or not it is 3 digits
		String lon_str="";
		if(latlon.length() > break_index + 2) {
		  lon_str = latlon.substring(
				    break_index+1,latlon.length());
		} else {
		  // lon is in next token
		  lon_str = items.nextToken();
		}
		if(lon_str.indexOf("W") > 0) {
		  lon = MyUtil.atof(
			 lon_str.substring(0,lon_str.length()-1));
		} else {
		  lon = -MyUtil.atof(
			 lon_str.substring(0,lon_str.length()-1));
		}
	      } else {
		Debug.println("Can't parse latlon in SoundingLoader");
		lat = 0;
		lon = 0;
	      }
	      elev = MyUtil.atof(items.nextToken());
	    } else {
	      // not a RAOB
	      lat = MyUtil.atof(items.nextToken());
	      lon = -MyUtil.atof(items.nextToken());
	      elev = MyUtil.atof(items.nextToken());
	    }
	  } else if (i == 3) {   //dont read line labeled '2' at all
	    dum = items.nextToken();
	    String station = items.nextToken();
	    Debug.println("Station = "+station);
	    Debug.println("Sounding at "+lat+"/"+lon+" "+elev);
	    if(range < 0) {
	      //no range info, not a model sounding
	      s = new Sounding(short_type,fcst_len,sounding_date,lat,lon,
			       station, instrument,CAPE,CIn,Helic,PW);
	    } else {
	      s = new Sounding(p.data_source,
			       short_type,fcst_len,sounding_date,lat,lon,
			       station, instrument,CAPE,CIn,Helic,PW,
			       bearing,range);
	    }
	  } else if (i >= 4) {
	    if(items.countTokens() < 7) {
	        //we have a bad line
	        Debug.println("Bad data line: "+line);
		//bad_sounding=true;
		bad_format=true;
	    } else {
	        line_type = Integer.parseInt(items.nextToken());
		// we seem to have trouble with lines of thpe
		// 7 = tropopause level and
		// 8 = max wind level, so ignore them
		if(line_type != 7 && line_type != 8) {
		  float p = MyUtil.atof(items.nextToken())/10.f;
		  //value input above is now in tenths of mb
		  float z = MyUtil.atof(items.nextToken());
		  float t = MyUtil.atof(items.nextToken());
		  float dp = MyUtil.atof(items.nextToken());
		  float wd = MyUtil.atof(items.nextToken());
		  float ws = MyUtil.atof(items.nextToken());
		  int data_descriptor = 0;
		  // get time, bearing, range if available
		  if(! items.hasMoreTokens()) {
		    level_date=null;
		    bearing=Sounding.MISSING;
		    range=Sounding.MISSING;
		  } else {
		    hhmm = MyUtil.atoi(items.nextToken());
		    sec_of_day = (hhmm/100)*3600 + (hhmm%100)*60;
		    delta_secs = sec_of_day - prev_sec_of_day;
		    prev_sec_of_day = sec_of_day;
		    //correct for day shift
		    if(delta_secs > 43200) {
		      delta_secs -= 86400;
		    }
		    if(delta_secs < -43200) {
		      delta_secs += 86400;
		    }
		    level_date = level_date.cloneDate();
		    level_date.addSecs(delta_secs);
		    bearing = MyUtil.atof(items.nextToken());
		    range = MyUtil.atof(items.nextToken());
		    // get baro flag if available
		    if(items.hasMoreTokens()) {
		      if(items.nextToken().equals("1")) {
			// barometric pressure was used in altitude
			data_descriptor=4;
		      }
		    }
		  }
		  if(z != Sounding.MISSING) {
	            if(t != Sounding.MISSING) {
		      t = t/10.f;
	            }
	            if(dp != Sounding.MISSING) {
		      dp = dp/10.f;
	            }
		    if(t != Sounding.MISSING ||
		       dp != Sounding.MISSING ||
		       wd != Sounding.MISSING ||
		       bearing != Sounding.MISSING ||
		       range != Sounding.MISSING ) {
		      s.addLevel(p,z,Sounding.MISSING,-1,t,dp,
				 Sounding.MISSING,wd,ws,
				 bearing,range,level_date,
				 data_descriptor);
		      some_levels=true;
		    }
		  }
		}
	    }
	  }
	}  //end of loop over lines within a sounding
	if(done || bad_sounding) {
	  Debug.println("break out due to bad sounding");
	  done=true;
	  break;  //break out of loop over soundings
	}

	if(some_levels) {
	  //generate mandatory levels
	  s.makeMands();
	  //calculate stability parameters
	  s.calcParameters();
	  
	  //add and show this sounding
	  p.add_show_sounding(s);
	}

      }  //end of loop over soundings
      Debug.println("End of loop over soundings");

      in.close();
      bfin.close();
      fin.close();
    } catch (FileNotFoundException e) {
      Debug.println("File not found: "+e);
    } catch (IOException e) {
      Debug.println("end of file for sounding:"+e);
      //displayArea.warn("Problem loading sounding");
    } catch (NoSuchElementException e) {
        bad_sounding=true;
        bad_format=true;
        Debug.println("Problem with sounding format: "+e);
    }

     if(bad_sounding) {
	    //we have a bad sounding
	    if(bad_raob) {
	        p.displayArea.warn(
		  "Requested RAOB time or location not available.");
	    } else if(bad_format) {
	        p.displayArea.warn("Problem with sounding format!");
	    } else {
	        p.displayArea.warn(line+": "+airport);
	    }
      }

    SoundingPanel.loading_soundings=false;
    p.displayArea.repaint();

  }


}
