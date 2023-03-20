import lib.*;
import sdg.*;
import java.util.*;
import java.io.*;
import java.sql.*;

public class SumUpdaterPersis_beta {
  Connection con_sum = null;
  public SumUpdaterPersis_beta(String model,int[] regions, UTCDate valid_date, int forecast_len)
    throws SQLException {
                       
  // generate sums for the period   
  con_sum =
    DriverManager.
    getConnection("jdbc:mysql://wolphin.fsl.noaa.gov/ruc_ua_sums3",
                  "wcron0_user","cohen_lee");
  if(!con_sum.isClosed()) {
    System.out.println("connected to ruc_ua_sums3 on MySQLserver");
  } else {
    Debug.println("PROBLEM connecting to ruc_ua_sums3!");
  }
  Statement stmt_ck = con_sum.createStatement();

  for(int i_reg=0;i_reg<regions.length;i_reg++) {
    int region = regions[i_reg];
    String table = model+"_Areg"+region;
    String field_list = "date,hour,fcst_len,mb10,N_dt,sum_ob_t,sum_dt,sum2_dt,"+
      "N_dw,sum_ob_ws,sum_model_ws,sum_du,sum_dv,sum2_dw,"+
      "N_dR,sum_ob_R,sum_dR,sum2_dR,N_dRoT,sum_dRoT,sum2_dRoT,N_dH,sum_dH,sum2_dH";
    // check if this table exists. If not, don't update sums
    ResultSet res_ck = stmt_ck.executeQuery("show tables like \"%"+table+"%\"");
    if(res_ck.next()) {
      // good to go
    Statement stmt_sum = con_sum.createStatement();
    UTCDate persis_start_date = valid_date.cloneDate();
    persis_start_date.addHours(-forecast_len);

    String query = 
"replace into "+table+" ("+field_list+")\n"+
"select o.date,o.hour,"+forecast_len+"\n"+
",ceil((o.press-20)/50)*5 as mb10\n"+
",count(o.t) as N_dt\n"+
",sum(o.t)/100 as sum_ob_t\n"+
",sum(o.t - m.t)/100 as sum_dt\n"+
",sum(pow(o.t - m.t,2))/100/100 as sum2_dt\n"+
",count(o.wd) as N_dw\n"+
",sum(o.ws)/100 as sum_ob_ws\n"+
",sum(if(o.ws is null,null,m.ws))/100 as sum_model_ws\n"+
",sum(o.ws*sin(o.wd/57.2658) -\n"+
"    m.ws*sin(m.wd/57.2658))/100 as sum_du\n"+
",sum(o.ws*cos(o.wd/57.2658) -\n"+
"     m.ws*cos(m.wd/57.2658))/100 as sum_dv\n"+
",sum(pow(o.ws,2)+pow(m.ws,2)- \n"+
"        2*o.ws*m.ws*cos((o.wd-m.wd)/57.2958))/\n"+
"        100/100\n"+
"   as sum2_dw\n"+
",count(o.rh - m.rh) as N_dR\n"+
",sum(o.rh - m.rh) as sum_dR\n"+
",sum(pow(o.rh - m.rh,2)) as sum2_dR\n"+
",sum(o.rh) as sum_ob_R\n"+
",0 as N_dRoT\n"+
",NULL as sum_dRoT\n"+
",NULL as sum2_dRoT\n"+
//",count(o.rh - m.rhot) as N_dRoT\n"+
//",sum(o.rh - m.rhot) as sum_dRoT\n"+
//",sum(pow(o.rh - m.rhot,2)) as sum2_dRoT\n"+
",count(o.z - m.z) as N_dH\n"+
",sum(o.z - m.z) as sum_dH\n"+
",sum(pow(o.z - m.z,2)) as sum2_dH\n"+
"from ruc_ua.RAOB as m, ruc_ua.RAOB as o, ruc_ua.metadata as meta\n"+
"where o.wmoid = m.wmoid\n"+
"and o.wmoid = meta.wmoid\n"+
"and o.press = m.press\n"+
"and find_in_set("+region+",meta.reg) > 0\n"+                      
"and o.date = '"+valid_date.getSQLDate()+"'\n"+
"and m.date = '"+persis_start_date.getSQLDate()+"'\n"+
"and o.hour = "+valid_date.getHour()+"\n"+
"and m.hour = "+persis_start_date.getHour()+"\n"+
"group by date,hour,mb10,m.fcst_len\n";
System.out.println("\nQUERY IS \n"+query);

 ResultSet rs_sum =
   stmt_sum.executeQuery(query);
 SQLWarning sqlw = rs_sum.getWarnings();
 if(sqlw != null) {
   Debug.println("SQLWarning is "+ sqlw);
   while((sqlw = sqlw.getNextWarning()) != null) {
     Debug.println("next SQLWarning is "+ sqlw);
   }
 }
 System.out.println(model+" region: "+region+
                    " fcst_len: "+forecast_len+" "+table+" "+valid_date+" "+rs_sum);
    } else {
      System.out.println("table "+table+" is missing. Skipping...");
    }
  }
  con_sum.close();
  }
}
