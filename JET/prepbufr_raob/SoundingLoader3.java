import lib.*;
import sdg.*;
import java.sql.*;
import java.net.*;
import java.io.*;
import java.util.*;
import java.util.zip.*;

/**
 * Change history:
 * 4-Jan-2022 updated to read soundings from the soundings.pbRAOBS table (RAOBs from prepBUFR)
 */
public class SoundingLoader3 {
  String directory;
  String data_source;
  String site;
  int wmoid;
  int fcst_len;
  UTCDate date;
  boolean analysis=false;
  Statement stmt;
  boolean has_level_dates = false;

public SoundingLoader3(Statement stmt) {
  this.stmt = stmt;
}

Sounding load_sounding(String directory, String data_source,String site,int wmoid,
		       float meta_lat,float meta_lon,float meta_elev,
		       int fcst_len,UTCDate date) {
  this.directory = directory;
  this.data_source = data_source;
  this.site = site;
  this.wmoid = wmoid;
  if((data_source.contains("RR") ||data_source.contains("RAP")) && fcst_len == -99) {
    //fcst_len = 0;
    analysis = true;
  } else {
    analysis = false;
  }
  this.fcst_len = fcst_len;
  this.date = date;
  Sounding s = null;
  String line="";
  String sounding_type=null;
  String short_type="";
  float range=Sounding.MISSING;
  float bearing=Sounding.MISSING;
  int hhmm,sec_of_day,delta_secs;
  int prev_sec_of_day=0;
  String instrument=null;
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
  BufferedInputStream bfin = null;
  DataInputStream in=null;
  GZIPInputStream gzin = null;
  boolean model = false;		// true for model soundings
  int start_secs = date.get1970Secs();
  int end_secs = start_secs + 3600;
  URL soundingURL = null;
  URLConnection urlc = null;
  File raob_input = null;
  File raob_output = null;
  File model_sounding = null;

  try {
    //get
    String access_file="";
    String enc_airport = URLEncoder.encode(site);
    in = get_from_database(stmt,data_source,Integer.toString(wmoid),date.getSQLDateTime(),fcst_len);

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
    boolean done=false;
    boolean some_levels=false;
    while (in != null && ! done) {   //loop over soundings
      i=-2;  //set up to read sounding
      sounding_date=null;
      instrument=null;
      range =Sounding.MISSING;
      while(true) {
	line=in.readLine();
	//Debug.println("Xue souding line=in.readline: "+line);
	  if(line == null) {
	    //Debug.println("End of file");
	    done=true;
	    break;
	  }
	  if(line.trim().equals("")) {
	    //Debug.println("blank line!");
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
	      //	    Debug.println("Xue in i==-1"+line);
	    sounding_type =  items.nextToken();
	    //	    Debug.println("Xue in sounding_type"+sounding_type);
	    some_levels=false;
	    //Debug.println("Sounding type is "+sounding_type);
	    if( sounding_type.startsWith("airport")) {
	      Debug.println("Bad airport");
	      bad_airport = true;
	      bad_sounding=true;
	      break;
	    } else if(sounding_type.startsWith("time") ||
		      line.indexOf("for this time") != -1) {
	      Debug.println("Bad time");
	      bad_time = true;
	      bad_sounding=true;
	      break;
	    } else if(sounding_type.startsWith("location")) {
	      Debug.println("Bad location");
	      bad_location = true;
	      bad_sounding=true;
	      break;
	    } else if(sounding_type.indexOf("<body>") != -1) {
	      Debug.println("Strange bad sounding");
	      bad_raob=true;
	      bad_sounding=true;
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
	      Debug.println("setting level_date to "+level_date);
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
	      } else if(maybe.equals("analysis")) {
                short_type="A";
                if((data_source.contains("RR") ||data_source.contains("RAP")) &&  fcst_len != -99) {
		  Debug.println("TROUBLE: forecast was requested "+
				"but analysis was read for RR/RAP models!");
		}
	      } else if(maybe.equals("dfi")) {
                short_type="DFI";
                if(fcst_len != 0) {
		  Debug.println("TROUBLE: forecast was requested "+
				"but analysis was read!");
		}
	      } else {
                short_type="F";
                if(fcst_len != Integer.parseInt(maybe)) {
		  Debug.println("TROUBLE: wrong forecast length "+
				" was read!");
		}
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
	    //Debug.println("flag = "+flag);
	    int hour = Integer.parseInt(items.nextToken());
	    int day = Integer.parseInt(items.nextToken());
	    String month_name = items.nextToken();
	    int month = UTCDate.get_month_num(month_name);
	    int year = Integer.parseInt(items.nextToken());
	    int min = 0;
	    //Debug.println("Hour is "+hour+", day is "+day+" month is "+month);
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
	      //Debug.println("special read for models "+line);
	      items = new StringTokenizer(line," ");
	      dum = items.nextToken(); //the word CAPE
	      CAPE = MyUtil.atof(items.nextToken());
	      dum = items.nextToken(); //the word CIn
	      CIn = MyUtil.atof(items.nextToken());
	      dum = items.nextToken(); //the word Helic
	      Helic = MyUtil.atof(items.nextToken());
	      dum = items.nextToken();  //the word PW
	      PW = MyUtil.atof(items.nextToken());
	      //Debug.println("CAPE = "+CAPE+", CIn = "+CIn+", Helic = "+Helic);
	    }
	  } else if (i == 1) {
	    dum = items.nextToken();  //'1'
	    dum = items.nextToken();  // don't know
	    int sdg_wmoid = MyUtil.atoi(items.nextToken());  // WMO ID number
	    if(sdg_wmoid != wmoid) {
	      Debug.println("TROUBLE: wmoid's differ: asked for: "+wmoid+
			    ", this sdg: "+sdg_wmoid+". this takes precidence");
	    }
	    wmoid = sdg_wmoid;
	    int NS = 1;		// Northern of Southern hemisphere
	    if(flag.equals("RAOB")) {
	      String latlon = items.nextToken();
	      //Debug.println("latlon is "+latlon+", of length"+
	      //    latlon.length());
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
		//Debug.println("lon_str is "+lon_str);
		if(lon_str.indexOf("E") > 0) {
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
	      // not a RAOB No "E" "W" to worry about, but the location may
	      // join together with a minus sign
	      String latlon = items.nextToken();
	      //Debug.println("latlon is "+latlon);
	      int break_index = latlon.lastIndexOf("-");
	      //Debug.println("break_index: "+break_index);
	      if(break_index > 2) {
		// the lat and lon ran together with a minus sign (so lon is minus)
		lat = MyUtil.atof(latlon.substring(0,break_index));
		lon = - MyUtil.atof(latlon.substring(break_index+1,latlon.length()));
	      } else {
		lat = MyUtil.atof(latlon);
		lon = MyUtil.atof(items.nextToken());
	      }
	      elev = MyUtil.atof(items.nextToken());
	    }
	    // check that soundings are near the right location
	    // model soundings indicate the grid point lat/lon, which had better
	    // be reasonably close to the RAOB (meta_) lat/lon.
	    double eps = 1.0;
	    if(flag.equals("RAOB")) {
	      // RAOBs should be very close
	      eps = 0.1;
	    }
	    if(Math.abs(lat - meta_lat) > eps ||
	       // lons from models are always positive, in both hemispheres!
	       Math.abs(Math.abs(lon) - Math.abs(meta_lon)) > eps ||
	       // elevation should be the same.
	       Math.abs(elev - meta_elev) > .01) {
	      Debug.println("Warning: location for "+wmoid+" differs: sdg/metadata:"+
			    " lats "  +lat+"/"+meta_lat+" lons: "+
			    " lons: " +lon+"/"+meta_lon+" lons: "+
			    " elevs: " +elev+"/"+meta_elev);
	    }
	  } else if (i == 3) {   //dont read line labeled '2' at all
	    dum = items.nextToken();
	    String station = items.nextToken();
	    //Debug.println("Station = "+station);
	    // see if this sounding has times for each level
	    while(items.hasMoreTokens()) {
	      dum = items.nextToken();
	      if(dum.equals("HHMM")) {
		has_level_dates = true;
		Debug.println("has level dates "+line);
		break;
	      } else {
		has_level_dates = false;
		//Debug.println("no level dates");
	      }
	    }
	    //Debug.println("Sounding at "+lat+"/"+lon+" "+elev);
	    if(range < 0) {
	      //no range info, not a model sounding
	      s = new Sounding(short_type,fcst_len,sounding_date,lat,lon,
			       station, wmoid, instrument,CAPE,CIn,Helic,PW);
	    } else {
	      s = new Sounding(data_source,
			       short_type,fcst_len,sounding_date,lat,lon,
			       station, wmoid,instrument,CAPE,CIn,Helic,PW,
			       bearing,range);
	    }
	  } else if (i >= 4) {
	    if(items.countTokens() < 7) {
	        //we have a bad line
	        Debug.println("Bad data line: "+line);
		bad_sounding=true;
		bad_format=true;
	    } else {
	        line_type = Integer.parseInt(items.nextToken());
		// we seem to have trouble with lines of type
		// 7 = tropopause level and
		// 8 = max wind level, so ignore them
		if(line_type != 7 && line_type != 8) {
		  float p = read_good(items.nextToken());
		  if(p != Sounding.MISSING) {
		    p /= 10.f;
		  }
		  //value input above is now in tenths of mb
		  float z = read_good(items.nextToken());
		  //  	          Debug.println("Xue SoundingLoader3 z "+z);
		  float t = read_good(items.nextToken());
		  float dp = read_good(items.nextToken());
		  float wd = read_good(items.nextToken());
		  float ws = read_good(items.nextToken());
		  int data_descriptor = 0;
		  // get time, bearing, range if available
		  if(! items.hasMoreTokens()) {
		    //Debug.println("setting level_date to null for "+line);
		    level_date=null;
		    bearing=Sounding.MISSING;
		    range=Sounding.MISSING;
		  } else if(has_level_dates) {
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
		    bearing = read_good(items.nextToken());
		    range = read_good(items.nextToken());
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
	if(done) {
	  done=true;
	  break;  //break out of loop over soundings
	}
	if(bad_sounding) {
	  Debug.println("break out due to bad sounding");
	  s = null;
	  done=true;
	  break;  //break out of loop over soundings
	}

      }  //end of loop over soundings
    //Debug.println("End of loop over soundings");

    } catch (FileNotFoundException e) {
      //Debug.println("File not found:\n"+e);
      //e.printStackTrace();
    } catch (IOException e) {
    //Debug.println("end of file for sounding:"+e);
    } catch (Exception e) {
        bad_sounding=true;
        bad_format=true;
        Debug.println("Problem with sounding format: "+e);
	e.printStackTrace();
    }
  try {
    in.close();
    bfin.close();
    fin.close();
    if(gzin != null) {
      gzin.close();
    }
  } catch (Exception e) {
    //Debug.println("Exception closing stream: "+e);
    //e.printStackTrace();
  }
  return s;
}

public DataInputStream get_from_database(Statement stmt,
					 String data_source,
					 String wmoid,
					 String valid_date,
					 int fcst_len) {
  String query;
  String table;
  ResultSet rs;
  String fcst_len_clause;
  String model_clause="";
  DataInputStream in = null;
  
  if(fcst_len >= 0) {
    fcst_len_clause= "and fcst_len = "+fcst_len+"\n";
  } else {
    fcst_len_clause= "order by "+fcst_len+"\n";
  }
  table = data_source+"_raob_soundings";
  query = "show tables like '"+table+"'";
  try {
    rs = stmt.executeQuery("use soundings_pb");
    rs = stmt.executeQuery(query);
    if(rs.next() == false) {
      //Debug.println(table+"doesn't exist");
      table = "model_raob_soundings";
      model_clause = "and model = '"+data_source+"'";
    }
  } catch (SQLException e) {
    Debug.println("wierd exception "+e);
  }
  query =
"select s from "+table+"\n"+
"where 1=1\n"+
"and cast(site as unsigned) = "+wmoid+"\n"+
"and time = '"+valid_date+"'\n"+
model_clause+"\n"+
fcst_len_clause+"\n";
  //Debug.println("\nQUERY IS \n"+query);
  try {
    rs = stmt.executeQuery(query);
    if(rs.next()) {
      Blob b = rs.getBlob("s");
      InputStream is1 = b.getBinaryStream();
      try {
	GZIPInputStream gz = new GZIPInputStream(is1);
	in = new DataInputStream(gz);
      } catch (IOException e) {
	Debug.println("problem with gunzip: "+e);
      }
    } else {
      //Debug.println("\nNo sounding for wmoid "+wmoid);
    }
  } catch (SQLException e) {
    Debug.println("query failed: "+e+" for wmoid "+wmoid);
  }
  return(in);
}			 

public float read_good(String s) {
  float result = Sounding.MISSING;
  if(!s.equals("99999")) {
    result = MyUtil.atof(s);
  }
  return result;
}

}
