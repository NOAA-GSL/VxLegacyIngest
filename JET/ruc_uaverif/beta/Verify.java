import lib.*;
import sdg.*;
import java.util.*;
import java.io.*;
import java.sql.*;

public class Verify {
    static Sounding s,s1,s2;
    static SoundingLoader3 sel;
    static Stability2 stab;
    static Vector wmoids_vec;
    static Vector names;
    static Vector lats_v;
    static Vector lons_v;
    static Vector elevs_v;

  /**
   * we use various ways to calculate RH from dewpoint, depending on how the dewpoint values
   * in the soundings were generated from the model vapor variable.
   */
public static String get_rh_calc(Statement stmt,String model) throws SQLException {
  String rh_calc;
  ResultSet rs =
    stmt.executeQuery("select calculator from ruc_ua.dp_to_rh_calculator_per_model where model = '"+
		      model+"'");
  if(rs.next()) {
    rh_calc = rs.getString("calculator");
  } else {
    rh_calc = "Fan-Whiting";
  }
  return(rh_calc);
}

  /**
   * models have different valid regions: the RUC covers little more than the contiguous US,
   * RR covers all of North AMerica, FIM and GFS are global.
   * We need to know this to determine which RAOBs we can match the model with.
   */
public static int get_max_region(Statement stmt,String model) throws SQLException {
  int max_region=0;
  ResultSet rs =
    stmt.executeQuery("select reg from ruc_ua.enclosing_region where model = '"+
		      model+"'");
  if(rs.next()) {
    max_region = rs.getInt("reg");
  } else {
    if(model.startsWith("RR") ||
       model.startsWith("isoRR")) {
      max_region = 6;
    } else if(model.startsWith("FIM") ||
	      model.startsWith("GFS")) {
      max_region = 7;
    } else {
      max_region = 0;
    }
  }
  return(max_region);
}

  /**
   * we also calculate statistics for sub-regions of each model.
   */
public static int[] get_regions(Statement stmt,String model) throws SQLException {
    ResultSet rs =
      stmt.executeQuery("select regions from ruc_ua.regions_per_model where model = '"+
			model+"'");
    if(rs.next()) {
      String reg_str = rs.getString("regions");
      StringTokenizer regs = new StringTokenizer(reg_str,",");
      int[] regions = new int[regs.countTokens()];
      int i=0;
      while(regs.hasMoreElements()) {
	regions[i++] = (new Integer((String)regs.nextElement())).intValue();
      }
      return regions;
    }
    if(model.startsWith("RR") ||
       model.startsWith("isoRR")) {
      int[] regions = {2,1,0,6};
      return(regions);
    } else if(model.startsWith("FIM") ||
	      model.startsWith("GFS")) {
      int[] regions = {2,1,0,6,8,9,10,11,7};
      return(regions);
    }
    int[] regions = {2,1,0};
    return(regions);
}

  /**
   * we calculate statistics for various forecast projections: The global models generate
   * forecasts for up to 10 days (240 hrs), but not for every hour; For other models
   * we focus on 0-12 hours or so.
   */
public static int[] get_fcst_lens(Statement stmt,String model) throws SQLException {
    ResultSet rs =
      stmt.executeQuery("select fcst_lens from ruc_ua.fcst_lens_per_model where model = '"+
			model+"'");
    if(rs.next()) {
      String fl_str = rs.getString("fcst_lens");
      StringTokenizer fls = new StringTokenizer(fl_str,",");
      int[] fcst_lens = new int[fls.countTokens()];
      int i=0;
      while(fls.hasMoreElements()) {
	fcst_lens[i++] = (new Integer((String)fls.nextElement())).intValue();
      }
      return fcst_lens;
    }
    int[] fcst_lens = {0,1,3,6,9,12};
    return(fcst_lens);
}
      
public static void main(String args[]) {
  Debug.DEBUG = true;
  wmoids_vec = new Vector();
  names = new Vector();
  lats_v = new Vector();
  lons_v = new Vector();
  elevs_v = new Vector();
  String rh_calculator;		// calculator name dp to rh
  int max_region;
  int i_arg=0;
  String directory = args[i_arg++];
  String model = args[i_arg++];
  int start_secs = Integer.parseInt(args[i_arg++]);
  int end_secs = Integer.parseInt(args[i_arg++]);
  int fcst_len = Integer.parseInt(args[i_arg++]);
  String desired_site = null;
  int desired_wmoid = -1;
  
  if(args.length > i_arg) {
    desired_site = args[i_arg++];
    System.out.println("desired site is "+desired_site);
  }
  if(false) {
    Map<String, String> variables = System.getenv();  
    for (Map.Entry<String, String> entry : variables.entrySet())  {  
      String name = entry.getKey();  
      String value = entry.getValue();  
      Debug.println(name + "=" + value);  
    }
  }
  String db_machine = System.getenv("db_machine");
  String db_url = "jdbc:mysql://"+db_machine+"/ruc_ua";
  String site="";
  int wmoid;
  int col=0;
  sel = new SoundingLoader3();
  // store into the database
  Connection con = null;
  Connection con_sum = null;
  try {
    Class.forName("com.mysql.jdbc.Driver").newInstance();
    con = DriverManager.getConnection(db_url,"wcron0_user","cohen_lee");
    if(!con.isClosed()) {
      System.out.println("connected to MySQLserver on "+db_machine);
    }
    Statement stmt = con.createStatement();
    int[] regions = get_regions(stmt,model);
    max_region = get_max_region(stmt,model);
    Debug.println("max region for "+model+" is "+max_region);
    Debug.print("regions for "+model+" are ");
    for(int i=0;i<regions.length;i++) {
      Debug.print(" "+regions[i]);
    }
    Debug.println("");
    int[] fcst_lens = {fcst_len};
    Debug.print("fcst_lens for "+model+" are ");
    for(int i=0;i<fcst_lens.length;i++) {
      Debug.print(" "+fcst_lens[i]);
    }
    Debug.println("");
    rh_calculator = get_rh_calc(stmt,model);
    Debug.println("calculator for RH from dewpoint is "+rh_calculator);
    
    // get raob information
    int region_matcher = (int)Math.pow(2,max_region);
    ResultSet rs =
      stmt.executeQuery("select wmoid,name,lat,lon,elev from metadata where reg & "+
			region_matcher +" = "+region_matcher +
			" order by name");
    while ( rs.next() ) {
      wmoids_vec.add(rs.getInt("wmoid"));
      names.add(rs.getString("name"));
      lats_v.add(rs.getInt("lat"));
      lons_v.add(rs.getInt("lon"));
      elevs_v.add(rs.getInt("elev"));		
    }
    String[] siteNames = new String[names.size()];
    int[] wmoids = new int[wmoids_vec.size()];
    float[] lats = new float[lats_v.size()];
    float[] lons = new float[lons_v.size()];
    float[] elevs = new float[elevs_v.size()];	    
    for(int i=0;i<wmoids.length;i++) {
      wmoids[i] = ((Integer)wmoids_vec.get(i)).intValue();
      siteNames[i] = (String)names.get(i);
      lats[i] = ((Integer)lats_v.get(i)).intValue()/100.f;
      lons[i] = ((Integer)lons_v.get(i)).intValue()/100.f;
      elevs[i] = ((Integer)elevs_v.get(i)).intValue();
    }
    if(desired_site != null) {
      for(int i=0;i<wmoids.length;i++)
	if(siteNames[i].equals(desired_site)||
	   desired_site.equals(""+wmoids[i])) {
	  desired_wmoid = wmoids[i];
	  break;
	}
    }
    
    UTCDate valid_date = new UTCDate(start_secs);
    //UTCDate stop_date = new UTCDate(2006,5,15,12,0,0);
    UTCDate stop_date = new UTCDate(end_secs);
    PreparedStatement replace_data =
      con.prepareStatement("replace into "+model+
			   " (wmoid,date,hour,fcst_len,press,z,t,dp,rh,wd,ws,version)"+
			   " values (?,?,?,?,?,?,?,?,?,?,?,?)");
    
    while(!valid_date.isAfter(stop_date)) {
      for(int ifl=0;ifl<fcst_lens.length;ifl++) {
	int n_good_sites=0;
	int n_too_low=0;
	int forecast_len = fcst_lens[ifl];
	col=2;
	System.out.println(forecast_len+"h fcst valid "+valid_date.getSQLDate()+" "+
			   valid_date.getHour());
	replace_data.setString(col++,valid_date.getSQLDate());
	replace_data.setInt(col++,valid_date.getHour());
	if(model.equals("RAOB")) {
	  replace_data.setNull(col++,Types.TINYINT);
	} else {
	  replace_data.setInt(col++,forecast_len);
	}
	int n_max = siteNames.length;
	if(desired_site != null && desired_wmoid != -1) {
	  n_max = 1;
	}
	for(int k=0;k<n_max;k++) {
	  site = siteNames[k];
	  wmoid = wmoids[k];
	  float lat = lats[k];
	  float lon = lons[k];
	  float elev = elevs[k];
	  if(n_max == 1) {
	    site = desired_site;
	    wmoid = desired_wmoid;
	  }
	  s1 = sel.load_sounding(directory,model,site,wmoid,lat,lon,elev,
				 forecast_len,valid_date);
	  if(s1 != null) {
	    n_good_sites++;
	    /* Stability2 interpolates soundings to 10mb levels and also generates
	       RH information from the dewpoints stored in the soundings. */
	    stab = new Stability2(s1,rh_calculator);
	    //Debug.println("stab is has "+stab.n_levels+" levels");
	    replace_data.setInt(1,s1.wmoid);
	    boolean bottom_adjusted=false;
	    for(int i=0;i<stab.n_levels;i++) {
	      if(n_max == 1) {
		System.out.println(MyUtil.goodRound(stab.pres[i],-1e10,1e10,0,2)+" "+
			      MyUtil.goodRound(stab.z[i],-1e10,1e10,0,2)+" "+
			      MyUtil.goodRound(stab.temp[i],-1e10,1e10,0,2)+" "+
			      MyUtil.goodRound(stab.dewpt[i],-1e10,1e10,0,2)+" "+
			      MyUtil.goodRound(stab.rh[i],-1e10,1e10,0,2)+" "+
			      MyUtil.goodRound(stab.wd[i],-1e10,1e10,0,1)+" "+
			      MyUtil.goodRound(stab.ws[i],-1e10,1e10,0,1));
	      }
	      col = 5;		// starting column to load
	      replace_data.setDouble(col++,stab.pres[i]);
	      // deal with z being unsigned; very rarely, we get a negative
	      // z which we cannot store in the db.
	      if(stab.z[i] < 0) {
		//Debug.println("station "+s1.wmoid+" altitude "+stab.z[i]+
		//	      " changed to zero, at pressure "+stab.pres[i]);
		bottom_adjusted=true;
		stab.z[i] = 0;
	      }
	      replace_data.setDouble(col++,stab.z[i]);
	      if(stab.temp[i] == Sounding.MISSING) {
		replace_data.setNull(col++,Types.INTEGER);
	      } else {
		double it = stab.temp[i]*100;
		if(it > 8388607) {
		  Debug.println("temp "+it/100.+" out of range for "+wmoid+
				" press "+stab.pres[i]+
				" fcst_len "+forecast_len+" at "+valid_date);
		  replace_data.setNull(col++,Types.INTEGER);
		} else {
		  replace_data.setDouble(col++,it);
		}
	      }
	      if(stab.dewpt[i] == Sounding.MISSING) {
		replace_data.setNull(col++,Types.INTEGER);
	      } else {
		replace_data.setDouble(col++,stab.dewpt[i]*100);
	      }
	      if(stab.rh[i] == Sounding.MISSING) {
		replace_data.setNull(col++,Types.TINYINT);
	      } else {
		replace_data.setDouble(col++,stab.rh[i]);
	      }	  
	      if(stab.wd[i] == Sounding.MISSING ||
		 stab.ws[i] == Sounding.MISSING) {
		replace_data.setNull(col++,Types.SMALLINT);
		replace_data.setNull(col++,Types.INTEGER);
	      } else {
		replace_data.setDouble(col++,stab.wd[i]);
		replace_data.setDouble(col++,stab.ws[i]*100);
	      }
	      int version = -3;
	      if(rh_calculator.equals("Fan-Whiting")) {
		version = 1;
	      } else if(rh_calculator.equals("FW-to-Wobus")) {
		version = 3;
	      } else if(rh_calculator.equals("Bolton")) {
		version = 2;
	      } else if(rh_calculator.equals("GFS-fixer-Wobus")) {
		version = 4;
	      } else if(rh_calculator.equals("Wobus")) {
		version = 5;
	      }
	      if(version == -3 ||
		 stab.temp[i] == Sounding.MISSING ||
		 stab.dewpt[i] == Sounding.MISSING) {
		replace_data.setNull(col++,Types.TINYINT);
	      } else {
		replace_data.setInt(col++,version);
	      }
	      replace_data.executeUpdate();
	    }
	    if(bottom_adjusted) {
	      n_too_low++;
	    }
	  } else {
	    //Debug.println(model+" "+site+" ("+wmoid+") "+forecast_len+" is missing!");
	  }
	}
	System.out.println(n_good_sites+" good sites, ("+
		      n_too_low+" below zero) for "+model+" fcst_len "+forecast_len+
		      " valid at "+valid_date);
	//replace_data.executeBatch();
	//replace_data.close();

	if(n_good_sites > 0 &&
	   !model.equals("RAOB") &&
	   desired_wmoid == -1) {
	  // Now generate sums for the period   
	  new SumUpdater(model,regions,valid_date,forecast_len,"cloudy");
	  new SumUpdater(model,regions,valid_date,forecast_len,"clear");
	  new SumUpdater(model,regions,valid_date,forecast_len,null);
	} // end n > 0 and not RAOB or specific wmoid requested
      } // end loop over forecast lengths
      valid_date.addHours(12);
    }
  } catch(Exception e) {
    System.out.println("Exception: "+e);
    e.printStackTrace();
  } finally {
    try {
      if(con != null) {
	con.close();
      }
    } catch(SQLException e) {
      System.out.println("SQL Exception: "+e.getMessage());
      System.exit(1);
    }
  }
  
}
}
  
