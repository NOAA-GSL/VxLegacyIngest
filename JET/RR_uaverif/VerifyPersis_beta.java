import lib.*;
import sdg.*;
import java.util.*;
import java.io.*;
import java.sql.*;
import java.util.Random;

public class VerifyPersis_beta {
    static Sounding s,s1,s2;
    static SoundingLoader3 sel;
    static Stability2 stab;
    static Vector wmoids_vec;
    static Vector names;
    static Vector lats_v;
    static Vector lons_v;
    static Vector elevs_v;

public static boolean has_rhot(Statement stmt,String model) throws SQLException {
  boolean result = false;
  ResultSet rs = stmt.executeQuery("describe ruc_ua."+model);
  while(rs.next()) {
    if(rs.getString("Field").equals("rhot")) {
      result=true;
      break;
    }
  }
  return(result);
}
  

public static String get_rh_calc(Statement stmt,String model) throws SQLException {
  String rh_calc=null;
  ResultSet rs =
    stmt.executeQuery("select calculator from ruc_ua.dp_to_rh_calculator_per_model where model = '"+
                      model+"'");
  if(rs.next()) {
    rh_calc = rs.getString("calculator");
  } else {
    // to avoid headaches in the future, we now exit if the rh_calculator isn't explicitly set
    // in ruc_ua.dp_to_rh_calculator_per_model
    System.err.println("You must have an entry for this model in "+
                       "ruc_ua.dp_to_rh_calculator_per_model!\n\n");
    System.exit(1);
  }
  return(rh_calc);
}
public static int get_max_region(Statement stmt,String model) throws SQLException {
  int max_region=0;
  ResultSet rs =
    stmt.executeQuery("select reg from ruc_ua.enclosing_region where model = '"+
                      model+"'");
  if(rs.next()) {
    max_region = rs.getInt("reg");
  } else {
    if(model.startsWith("RR") ||
       model.startsWith("RAP") ||
       model.startsWith("isoRR")) {
      max_region = 6;
    } else if(model.startsWith("HRRR")) {
      if(model.startsWith("HRRR_AK")) {
        max_region = 13;
      } else if(model.startsWith("HRRR_HI")) {
        max_region = 19;
      } else {
        max_region = 14;
      }
    } else if(model.startsWith("FIM") ||
              model.startsWith("GFS")) {
      max_region = 7;
    } else {
      max_region = 0;
    }
  }
  return(max_region);
}
 
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
       model.startsWith("RAP") ||
       model.startsWith("isoRR")) {
      int[] regions = {2,1,0,6,14,13,17,18,19};
      return(regions);
    } else if(model.startsWith("HRRR")) {
      if(model.startsWith("HRRR_AK")) {
        int[] regions = {13};
        return(regions);
      } else if(model.startsWith("HRRR_HI")) {
        int[] regions = {19};
        return(regions);
      } else {
        int[] regions = {5,2,1,14,15,16,17,18,13,19};
        return(regions);
      }
    } else if(model.startsWith("FIM") ||
              model.startsWith("GFS")) {
      int[] regions = {2,1,0,6,8,9,10,11,7,14,13,19};
      return(regions);
    }
    int[] regions = {5,2,1,14,15,16,17,18,13,19,0,6,8,9,10,11,7};
    return(regions);
}

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
    int[] fcst_lens = {0,1,3,6,9,12,18};
    return(fcst_lens);
}
      
public static void main(String args[]) {
  Debug.DEBUG = true;
  Debug.STDIO = true;
  wmoids_vec = new Vector();
  names = new Vector();
  lats_v = new Vector();
  lons_v = new Vector();
  elevs_v = new Vector();
  String rh_calculator;         // calculator name dp to rh
  int max_region;
  int i_arg=0;
  int n_max = 0;
  String directory = args[i_arg++];
  String model = args[i_arg++];
  int start_secs = Integer.parseInt(args[i_arg++]);
  int end_secs = Integer.parseInt(args[i_arg++]);
  int fcst_len = Integer.parseInt(args[i_arg++]);
  boolean has_rhot=false;       // true if we're to calculate RH wrt obs T
  String field_list = "wmoid,date,hour,fcst_len,press,z,t,dp,rh,wd,ws,version";

  String desired_site = null;
  int desired_wmoid = -1;
  
  if(args.length > i_arg) {
    desired_site = args[i_arg++];
    n_max = 1;
    Debug.println("desired site is "+desired_site);
  }
  
  String site="";
  int wmoid;
  int col=0;
  // store into the database
  Connection con = null;
  Connection con_sum = null;
  try {
    Class.forName("com.mysql.jdbc.Driver").newInstance();
    con =
      DriverManager.
      getConnection("jdbc:mysql://wolphin.fsl.noaa.gov/ruc_ua",
                    "wcron0_user","cohen_lee");
    if(!con.isClosed()) {
      Debug.println("connected to MySQLserver");
    }
    Statement stmt = con.createStatement();
    sel = new SoundingLoader3(stmt);
    //Debug.println("");
    int[] fcst_lens = {fcst_len};
    //System.out.print("fcst_lens for "+model+" are ");
    for(int i=0;i<fcst_lens.length;i++) {
      //System.out.print(" "+fcst_lens[i]);
    }
    int[] regions = get_regions(stmt,model);
    max_region = get_max_region(stmt,model);
    Debug.println("max region for "+model+" is "+max_region);
    System.out.print("regions for "+model+" are ");
    for(int i=0;i<regions.length;i++) {
      System.out.print(" "+regions[i]);
    }
    Debug.println("");
    UTCDate valid_date = new UTCDate(start_secs);
    UTCDate stop_date = new UTCDate(end_secs);
    String curDir = System.getProperty("user.dir");
    Debug.println(curDir);

    while(!valid_date.isAfter(stop_date)) {
      for(int ifl=0;ifl<fcst_lens.length;ifl++) {
        int forecast_len = fcst_lens[ifl];
	new SumUpdaterPersis_beta(model,regions,valid_date,forecast_len);
      } // end loop over fcst lengths
      valid_date.addHours(12);
    } // end loop over valid dates
  } catch(Exception e) {
    Debug.println("Exception: "+e);
    e.printStackTrace();
  } finally {
    try {
      if(con != null) {
        con.close();
      }
    } catch(SQLException e) {
      Debug.println("SQL Exception: "+e.getMessage());
      System.exit(1);
    }
  }
  
}
}
