import lib.*;
import sdg.*;
import java.util.*;
import java.io.*;
import java.sql.*;
import java.util.Random;

public class Verify3_beta {
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
  String query = "select reg from ruc_ua.enclosing_region where model = '"+model+"'";
  Debug.println("query is "+query);
  int max_region = 7;
  ResultSet rs =
    stmt.executeQuery(query);
  if(rs.next()) {
    max_region = rs.getInt("reg");
  } else {
    if(model.startsWith("RR") ||
       model.startsWith("RAP") ||
       model.startsWith("isoRR")) {
      max_region = 6;
    } else if(model.startsWith("FIM") ||
              model.startsWith("GFS")) {
    } else if(model.contains("AK")) {
      max_region = 13;
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
    if(model.startsWith("RRFS_NA_13km")) {
      int[] regions = {5,2,1,14,15,16,17,18,13,19};
    } else if(model.startsWith("RRFS")) {
      int[] regions = {5,2,1,14,15,16,17,18,13,19};
    } else if(model.startsWith("RR") ||
       model.startsWith("RAP") ||
       model.startsWith("isoRR")) {
      int[] regions = {2,1,0,6,14,13,17,18,19};
      return(regions);
    } else if(model.startsWith("HRRR")) {
      if(model.contains("AK")) {
        int[] regions = {13};
        return(regions);
      } else if(model.startsWith("HRRRAK")) {
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
      int[] regions = {2,1,0,6,8,9,10,11,7};
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
    rh_calculator = get_rh_calc(stmt,model);
    Debug.println("calculator for RH from dewpoint is "+rh_calculator);

    has_rhot = has_rhot(stmt,model);
    if(has_rhot) {
      field_list += ",rhot";
    }
    
    // get raob information
    int region_matcher = (int)Math.pow(2,max_region);
    String site_matcher = "";
    if(desired_site != null) {
      site_matcher = " and wmoid = "+desired_site;
    }
    ResultSet rs = stmt.executeQuery("use ruc_ua");
    rs = stmt.executeQuery("select wmoid,name,lat,lon,elev from metadata where reg & "+
			   region_matcher +" = "+region_matcher + " "+
			   site_matcher +" order by name");
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
    UTCDate stop_date = new UTCDate(end_secs);
    String curDir = System.getProperty("user.dir");
    Debug.println(curDir);

    File mytempdir = new File("./tmp");
    File weitemp = File.createTempFile("load_db", ".txt",mytempdir);
    BufferedWriter out = new BufferedWriter(new FileWriter(weitemp));
    Debug.println(weitemp.getName());

    while(!valid_date.isAfter(stop_date)) {
      for(int ifl=0;ifl<fcst_lens.length;ifl++) {
        int n_good_sites=0;
        int n_too_low=0;
        int forecast_len = fcst_lens[ifl];
        col=2;
        Debug.println(fcst_len+"h fcst valid "+valid_date.getSQLDate()+" "+
                      valid_date.getHour());

        String out_fcst_len;
        if(model.equals("RAOB")) {
          out_fcst_len =  "\\N";
        } else {
          out_fcst_len = Integer.toString(forecast_len);
        }
        n_max = siteNames.length;
        if(desired_site != null && desired_wmoid != -1) {
          n_max = 1;
        }
        StringBuffer outc = new StringBuffer();
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
	  //Debug.println("s1 is "+s1);
          if(s1 != null) {
            System.out.print(site+" ");
            n_good_sites++;

	    //            Debug.println("Xue s1 = "+ s1);
            stab = new Stability2(s1,rh_calculator);
            //Debug.println("stab "+stab+" has "+stab.n_levels+" levels");
            // get RAOB, if we want to calculate rhot
            if(has_rhot) {
              Stability2 stab_raob = new Stability2(stmt,"RAOB",site,wmoid,forecast_len,valid_date);
              int i=0;
              int j=0;
              for(;i<stab.n_levels && j<stab_raob.n_levels;) {
                if(stab.pres[i] > stab_raob.pres[j]) {
                  i++;
                } else if(stab.pres[i] < stab_raob.pres[j]) {
                  j++;
                } else{
                  if(stab.dewpt[i] != Sounding.MISSING && stab_raob.temp[j] != Sounding.MISSING) {
                    stab.rhot[i] =
                      Stability2.svpWobus(stab.dewpt[i]+273.15)/Stability2.svpWobus(stab_raob.temp[j]+273.15) * 100;
                  }
                  i++;
                  j++;
                }
              }
            }
            boolean bottom_adjusted=false;
            for(int i=0;i<stab.n_levels;i++) {

              if(n_max == 1) {
                Debug.println(MyUtil.goodRound(stab.pres[i],-1e10,1e10,0,2)+" "+
                              MyUtil.goodRound(stab.z[i],-1e10,1e10,0,2)+" "+
                              MyUtil.goodRound(stab.temp[i],-1e10,1e10,0,2)+" "+
                              MyUtil.goodRound(stab.dewpt[i],-1e10,1e10,0,2)+" "+
                              MyUtil.goodRound(stab.rh[i],-1e10,1e10,0,2)+" "+
                              MyUtil.goodRound(stab.wd[i],-1e10,1e10,0,1)+" "+
                              MyUtil.goodRound(stab.ws[i],-1e10,1e10,0,1));
              }
              col = 5;          // starting column to load
              outc.append(s1.wmoid+",");
              outc.append(valid_date.getSQLDate()+",");
              outc.append(valid_date.getHour()+",");
              outc.append(out_fcst_len+",");
              outc.append(stab.pres[i]+",");

              // deal with z being unsigned; very rarely, we get a negative
              // z which we cannot store in the db.
              if(stab.z[i] < 0) {
                //Debug.println("station "+s1.wmoid+" altitude "+stab.z[i]+
                //            " changed to zero, at pressure "+stab.pres[i]);
                bottom_adjusted=true;
                stab.z[i] = 0;
              }
	      //               Debug.println("Xue station "+s1.wmoid+" altitude "+stab.z[i]+" pressure "+stab.pres[i]);
              outc.append(stab.z[i]+",");
              if(stab.temp[i] == Sounding.MISSING) {
                outc.append("\\N,");
              } else {
                double it = stab.temp[i]*100;
                if(it > 8388607) {
                  Debug.println("temp "+it/100.+" out of range for "+wmoid+
                                " press "+stab.pres[i]+
                                " fcst_len "+forecast_len+" at "+valid_date);
                  outc.append("\\N,");
                } else {
                  outc.append(it+",");
                }
              }
              if(stab.dewpt[i] == Sounding.MISSING) {
                outc.append("\\N,");
              } else {
                double out_dewpt = stab.dewpt[i]*100;
                outc.append(out_dewpt+",");
              }
              if(stab.rh[i] == Sounding.MISSING) {
                outc.append("\\N,");
              } else {
                outc.append(stab.rh[i]+",");
              }   
              if(stab.wd[i] == Sounding.MISSING ||
                 stab.ws[i] == Sounding.MISSING) {
                outc.append("\\N,");
                outc.append("\\N,");

              } else {
                outc.append(stab.wd[i]+",");
                double ws = stab.ws[i]*100;
                outc.append(ws+",");

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
                outc.append("\\N");
              } else {
                outc.append(version);
              }
              if(has_rhot) {
                if(stab.rhot[i] == Sounding.MISSING) {
                  outc.append(",\\N");
                } else {
                  outc.append(","+stab.rhot[i]);
                }
              }
              outc.append("\n");
            }
            if(bottom_adjusted) {
              n_too_low++;
            }
          } else {
            //Debug.println(model+" "+site+" ("+wmoid+") "+forecast_len+" is missing!");
          }
        }
        String outstring = outc.toString();
        out.write(outstring);
        out.close();
        String ld_cmd =
          "LOAD DATA concurrent LOCAL INFILE 'tmp/"+weitemp.getName()+"' REPLACE INTO table ruc_ua."+model
          +" columns terminated by ',' lines terminated by '\n' "
          +"("+field_list+")";
        Debug.println(ld_cmd);
	int before_secs = (new UTCDate()).get1970Secs();
        PreparedStatement load_data = con.prepareStatement(ld_cmd);
        int res_load =  load_data.executeUpdate();
	int after_secs = (new UTCDate()).get1970Secs();
	int load_secs = after_secs - before_secs;
        Debug.println("db rows updated: "+ res_load+" in "+load_secs+" seconds");

        Debug.println("\n"+n_good_sites+" good sites, ("+
                      n_too_low+" below zero) for "+model+" fcst_len "+forecast_len+
                      " valid at "+valid_date);

	//        Debug.println("deleting "+weitemp.getName());
        //weitemp.delete();

        if(n_good_sites <= 0) {
          Debug.println("\n");
        } else {
        if(!model.equals("RAOB") &&
           desired_wmoid == -1) {
	  new DealWithResids(model,valid_date,fcst_len);
          // Now generate sums for the period
          new SumUpdater_beta(model,regions,valid_date,forecast_len);
        }
        } // end good sites > 0
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