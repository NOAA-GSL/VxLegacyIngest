import lib.*;
import sdg.*;
import java.util.*;
import java.io.*;
import java.sql.*;

public class SumUpdater {
  Connection con_sum = null;
  public SumUpdater(String model,int[] regions, UTCDate valid_date, int forecast_len, String hydro)
    throws SQLException {
                       
  // generate sums for the period   
  con_sum =
    DriverManager.
    getConnection("jdbc:mysql://wolphin.fsl.noaa.gov/ruc_ua_pb_sums2",
                  "wcron0_user","cohen_lee");
  if(!con_sum.isClosed()) {
    System.out.println("connected to ruc_ua_pb_sums2 on MySQLserver");
  } else {
    Debug.println("PROBLEM connecting to ruc_ua_pb_sums2!");
  }
  // see if new-style summary tables exist
  boolean A_tables = false;
  String table = model+"_Areg";
  Statement stmt_ck = con_sum.createStatement();
  ResultSet res_ck = stmt_ck.executeQuery("show tables like \"%"+table+"%\"");
  if(res_ck.next()) {
    //System.out.println("NEW TABLE EXISTS\n");
    A_tables = true;
  } else {
    //System.out.println("NO NEW TABLE\n");
    A_tables = false;
  }
  for(int i_reg=0;i_reg<regions.length;i_reg++) {
    int region = regions[i_reg];
    String field_list = "date,hour,fcst_len,mb10,N_dt,sum_dt,sum2_dt,"+
      "N_dw,sum_du,sum_dv,sum2_dw,N_dR,sum_dR,sum2_dR";
    if(A_tables) {
      table = model+"_Areg"+region;
      field_list += ",sum_ob_ws,sum_model_ws";
    } else {
      table = model+"_reg"+region;
    }
    if(hydro != null) {
      table += "_"+hydro;
    }
    // check if this table exists. If not, don't update sums
    res_ck = stmt_ck.executeQuery("show tables like \"%"+table+"%\"");
    if(res_ck.next()) {
      // good to go
    Statement stmt_sum = con_sum.createStatement();
    ResultSet rsd = stmt_sum.executeQuery("describe "+table);
    boolean has_heights = false;
    boolean has_ob_t = false;
    boolean has_ob_R = false;
    boolean has_rhot = false;
    while(rsd.next()) {
      String fname = rsd.getString("Field");
      if(fname.equals("N_dH")) {
        has_heights = true;
      } else if(fname.equals("sum_ob_t")) {
        has_ob_t = true;
      } else if(fname.equals("sum_ob_R")) {
        has_ob_R = true;
      } else if(fname.equals("N_dRoT")) {
        has_rhot = true;
      }
    }
    // set up proper order for the field list, so it matches the select statement below
    if(has_heights) {
        field_list += ",N_dh,sum_dH,sum2_dH";
    }
    if(has_ob_t) {
      field_list += ",sum_ob_t";
    }
    if(has_ob_R) {
      field_list += ",sum_ob_R";
    }
    if(has_rhot) {
      field_list += ",N_dRoT,sum_dRoT,sum2_dRoT";
    }
    String query = 
"replace into "+table+" ("+field_list+")\n"+
"select M.date,M.hour,M.fcst_len\n"+
",ceil((R.press-20)/50)*5 as mb10\n"+
",count(R.t) as N_dt\n"+
",sum(R.t - M.t)/100 as sum_dt\n"+
",sum(pow(R.t - M.t,2))/100/100 as sum2_dt\n"+
",count(R.wd) as N_dw\n"+
",sum(R.ws*sin(R.wd/57.2658) -\n"+
"    M.ws*sin(M.wd/57.2658))/100 as sum_du\n"+
",sum(R.ws*cos(R.wd/57.2658) -\n"+
"     M.ws*cos(M.wd/57.2658))/100 as sum_dv\n"+
",sum(pow(R.ws,2)+pow(M.ws,2)- \n"+
"        2*R.ws*M.ws*cos((R.wd-M.wd)/57.2958))/\n"+
"        100/100\n"+
"   as sum2_dw\n"+
",count(R.rh - M.rh) as N_dR\n"+
",sum(R.rh - M.rh) as sum_dR\n"+
",sum(pow(R.rh - M.rh,2)) as sum2_dR\n";
if(A_tables) {
  query +=
    ",sum(R.ws)/100 as sum_ob_ws\n"+
    ",sum(if(R.ws is null,null,M.ws))/100 as sum_model_ws\n";
}
if(has_heights) {
  query +=
    ",count(R.z - M.z) as N_dH\n"+
    ",sum(R.z - M.z) as sum_dH\n"+
    ",sum(pow(R.z - M.z,2)) as sum2_dH\n";
}
if(has_ob_t) {
  query +=
    ",sum(R.t)/100 as sum_ob_t\n";
}
if(has_ob_R) {
  query +=
    ",sum(R.rh) as sum_ob_R\n";
}
 if(has_rhot) {
   query +=
     ",count(R.rh - M.rhot) as N_dRoT\n"+
     ",sum(R.rh - M.rhot) as sum_dRoT\n"+
     ",sum(pow(R.rh - M.rhot,2)) as sum2_dRoT\n";
 }
query +=
"from ruc_ua_pb."+model+" as M, ruc_ua_pb.RAOB as R, ruc_ua_pb.metadata as metad\n";
if(hydro != null) {
  query += ", soundings."+model+"_raob_soundings as s\n";
}
 query +=
"where R.wmoid = metad.wmoid\n"+
"and R.wmoid = M.wmoid\n"+
"and R.date = M.date\n"+
"and R.hour = M.hour\n"+
"and R.press = M.press\n"+
"and find_in_set("+region+",reg) > 0\n"+                      
"and R.date = '"+valid_date.getSQLDate()+"'\n"+
"and M.date = '"+valid_date.getSQLDate()+"'\n"+
"and R.hour = "+valid_date.getHour()+"\n"+
"and M.hour = "+valid_date.getHour()+"\n"+
"and M.fcst_len = "+forecast_len+"\n";
if(hydro != null) {
  query +=
"and s.site = m.name\n"+
"and s.time = '"+valid_date.getSQLDateTime()+"'\n"+
"and s.fcst_len = "+forecast_len+"\n";
  if(hydro.equals("cloudy")) {
    query +=
"and s.hydro is not null\n";
  } else if(hydro.equals("clear")) {
    query +=
"and s.hydro is null\n";
  }
}
query +=
"group by date,hour,mb10,fcst_len\n";
//Debug.println("\nQUERY IS \n"+query);
//System.out.print("\nQUERY IS \n"+query);


 ResultSet rs_sum =
   stmt_sum.executeQuery(query);
 String msg = rs_sum.toString();
 int index = msg.indexOf("count of");
 String update_count = msg.substring(index+9);
 SQLWarning sqlw = rs_sum.getWarnings();
 if(sqlw != null) {
   Debug.println("SQLWarning is "+ sqlw);
   while((sqlw = sqlw.getNextWarning()) != null) {
     Debug.println("next SQLWarning is "+ sqlw);
   }
 }
 System.out.println("region: "+region+
                    " fcst_len: "+forecast_len+" valid: "+valid_date.getSQLDateTime()+" "+table+" count: "+update_count);
    } else {
      System.out.println("table "+table+" is missing. Skipping...");
    }
  }
  con_sum.close();
  }
}
