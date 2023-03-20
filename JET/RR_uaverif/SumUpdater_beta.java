import lib.*;
import sdg.*;
import java.util.*;
import java.io.*;
import java.sql.*;

public class SumUpdater_beta {
  Connection con_sum = null;
  public SumUpdater_beta(String model,int[] regions, UTCDate valid_date, int forecast_len)
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

    String query = 
"replace into "+table+" ("+field_list+")\n"+
"select ruc_ua."+model+".date,ruc_ua."+model+".hour,ruc_ua."+model+".fcst_len\n"+
",ceil((ruc_ua.RAOB.press-20)/50)*5 as mb10\n"+
",count(ruc_ua.RAOB.t) as N_dt\n"+
",sum(ruc_ua.RAOB.t)/100 as sum_ob_t\n"+
",sum(ruc_ua.RAOB.t - ruc_ua."+model+".t)/100 as sum_dt\n"+
",sum(pow(ruc_ua.RAOB.t - ruc_ua."+model+".t,2))/100/100 as sum2_dt\n"+
",count(ruc_ua.RAOB.wd) as N_dw\n"+
",sum(ruc_ua.RAOB.ws)/100 as sum_ob_ws\n"+
",sum(if(ruc_ua.RAOB.ws is null,null,ruc_ua."+model+".ws))/100 as sum_model_ws\n"+
",sum(ruc_ua.RAOB.ws*sin(ruc_ua.RAOB.wd/57.2658) -\n"+
"    ruc_ua."+model+".ws*sin(ruc_ua."+model+".wd/57.2658))/100 as sum_du\n"+
",sum(ruc_ua.RAOB.ws*cos(ruc_ua.RAOB.wd/57.2658) -\n"+
"     ruc_ua."+model+".ws*cos(ruc_ua."+model+".wd/57.2658))/100 as sum_dv\n"+
",sum(pow(ruc_ua.RAOB.ws,2)+pow(ruc_ua."+model+".ws,2)- \n"+
"        2*ruc_ua.RAOB.ws*ruc_ua."+model+".ws*cos((ruc_ua.RAOB.wd-ruc_ua."+model+".wd)/57.2958))/\n"+
"        100/100\n"+
"   as sum2_dw\n"+
",count(ruc_ua.RAOB.rh - ruc_ua."+model+".rh) as N_dR\n"+
",sum(ruc_ua.RAOB.rh) as sum_ob_R\n"+
",sum(ruc_ua.RAOB.rh - ruc_ua."+model+".rh) as sum_dR\n"+
",sum(pow(ruc_ua.RAOB.rh - ruc_ua."+model+".rh,2)) as sum2_dR\n"+
",count(ruc_ua.RAOB.rh - ruc_ua."+model+".rhot) as N_dRoT\n"+
",sum(ruc_ua.RAOB.rh - ruc_ua."+model+".rhot) as sum_dRoT\n"+
",sum(pow(ruc_ua.RAOB.rh - ruc_ua."+model+".rhot,2)) as sum2_dRoT\n"+
",count(ruc_ua.RAOB.z - ruc_ua."+model+".z) as N_dH\n"+
",sum(ruc_ua.RAOB.z - ruc_ua."+model+".z) as sum_dH\n"+
",sum(pow(ruc_ua.RAOB.z - ruc_ua."+model+".z,2)) as sum2_dH\n"+
"from ruc_ua."+model+", ruc_ua.RAOB, ruc_ua.metadata as m\n"+
"where ruc_ua.RAOB.wmoid = m.wmoid\n"+
"and ruc_ua.RAOB.wmoid = ruc_ua."+model+".wmoid\n"+
"and ruc_ua.RAOB.date = ruc_ua."+model+".date\n"+
"and ruc_ua.RAOB.hour = ruc_ua."+model+".hour\n"+
"and ruc_ua.RAOB.press = ruc_ua."+model+".press\n"+
"and find_in_set("+region+",reg) > 0\n"+                      
"and ruc_ua.RAOB.date = '"+valid_date.getSQLDate()+"'\n"+
"and ruc_ua."+model+".date = '"+valid_date.getSQLDate()+"'\n"+
"and ruc_ua.RAOB.hour = "+valid_date.getHour()+"\n"+
"and ruc_ua."+model+".hour = "+valid_date.getHour()+"\n"+
"and ruc_ua."+model+".fcst_len = "+forecast_len+"\n"+
"group by date,hour,mb10,fcst_len\n";
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
                    " fcst_len: "+forecast_len+" "+table+" "+rs_sum);
    } else {
      System.out.println("table "+table+" is missing. Skipping...");
    }
  }
  con_sum.close();
  }
}
