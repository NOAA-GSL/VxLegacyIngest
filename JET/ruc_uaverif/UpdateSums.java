import lib.*;
import sdg.*;
import java.util.*;
import java.io.*;
import java.sql.*;

// the classes below are at /w3/mysql/mysql-connector-java-3.1.13-bin.jar
//import com.mysql.jdbc.*;

public class UpdateSums {

    public static void main(String args[]) {
	Debug.DEBUG = true;
	String[] models = {"dev","dev2","Bak20","Op20"};
	int[] fcst_lens = {0,1,3,6,9};
	int start_secs = Integer.parseInt(args[0]);
	int end_secs = Integer.parseInt(args[1]);
	Connection con_sum = null;
	try {
	    Class.forName("com.mysql.jdbc.Driver").newInstance();
	    con_sum =
	      DriverManager.
	      getConnection("jdbc:mysql://wolphin.fsl.noaa.gov/ruc_ua_sums2",
			    "writer","amt1234");
	    if(!con_sum.isClosed()) {
	      Debug.println("connected to ruc_ua_sums2 on MySQLserver");
	    } else {
	      Debug.println("PROBLEM connecting to ruc_ua_sums2!");
	    }
	    
	    UTCDate valid_date = new UTCDate(start_secs);
	    UTCDate stop_date = new UTCDate(end_secs);
  
	    while(valid_date.isBefore(stop_date)) {
	      for(int i_mod=0;i_mod<models.length;i_mod++) {
		String model = models[i_mod];
		for(int i_len=0;i_len<fcst_lens.length;i_len++) {
		  int forecast_len = fcst_lens[i_len];
		    int n_regions = 3;
		    if(model.equals("dev2")) {
			n_regions = 5;		// include reg 3: non-GPS raobs, 4: GPS raobs
		    }
		    for(int region=0;region<n_regions;region++) {
			Statement stmt_sum = con_sum.createStatement();
			String query = 
"replace into "+model+"_reg"+region+"\n"+
"select ruc_ua."+model+".date,ruc_ua."+model+".hour,ruc_ua."+model+".fcst_len,\n"+
"ceil((ruc_ua.RAOB.press-20)/50)*5 as mb10,\n"+
"count(ruc_ua.RAOB.t) as N_dt,\n"+
"sum(ruc_ua.RAOB.t - ruc_ua."+model+".t)/100 as sum_dt,\n"+
"sum(pow(ruc_ua.RAOB.t - ruc_ua."+model+".t,2))/100/100 as sum2_dt,\n"+
"count(ruc_ua.RAOB.wd) as N_dw,\n"+
"sum(ruc_ua.RAOB.ws*sin(ruc_ua.RAOB.wd/57.2658) -\n"+
"    ruc_ua."+model+".ws*sin(ruc_ua."+model+".wd/57.2658))/100 as sum_du,\n"+
"sum(ruc_ua.RAOB.ws*cos(ruc_ua.RAOB.wd/57.2658) -\n"+
"     ruc_ua."+model+".ws*cos(ruc_ua."+model+".wd/57.2658))/100 as sum_dv,\n"+
"sum(pow(ruc_ua.RAOB.ws,2)+pow(ruc_ua."+model+".ws,2)- \n"+
"	 2*ruc_ua.RAOB.ws*ruc_ua."+model+".ws*cos((ruc_ua.RAOB.wd-ruc_ua."+model+".wd)/57.2958))/\n"+
"	 100/100\n"+
"   as sum2_dw,\n"+
"count(ruc_ua.RAOB.rh - ruc_ua."+model+".rh) as N_dR,\n"+
"sum(ruc_ua.RAOB.rh - ruc_ua."+model+".rh) as sum_dR,\n"+
"sum(pow(ruc_ua.RAOB.rh - ruc_ua."+model+".rh,2)) as sum2_dR\n"+
"from ruc_ua."+model+", ruc_ua.RAOB, ruc_ua.metadata\n"+
"where ruc_ua.RAOB.wmoid = metadata.wmoid\n"+
"and ruc_ua.RAOB.wmoid = ruc_ua."+model+".wmoid\n"+
"and ruc_ua.RAOB.date = ruc_ua."+model+".date\n"+
"and ruc_ua.RAOB.hour = ruc_ua."+model+".hour\n"+
"and ruc_ua.RAOB.press = ruc_ua."+model+".press\n"+
 //"and reg like '%"+region+"%'\n"+
"and reg & "+Math.pow(2,region)+" = "+Math.pow(2,region)+		      
"and ruc_ua.RAOB.date = '"+valid_date.getSQLDate()+"'\n"+
"and ruc_ua."+model+".date = '"+valid_date.getSQLDate()+"'\n"+
"and ruc_ua.RAOB.hour = "+valid_date.getHour()+"\n"+
"and ruc_ua."+model+".hour = "+valid_date.getHour()+"\n"+
"and ruc_ua."+model+".fcst_len = "+forecast_len+"\n"+
"group by date,hour,mb10,fcst_len\n";
			Debug.println("\nQUERY IS \n"+query);
			ResultSet rs_sum =
			    stmt_sum.executeQuery(query);
			SQLWarning sqlw = rs_sum.getWarnings();
			if(sqlw != null) {
			  Debug.println("SQLWarning is "+ sqlw);
			  while((sqlw = sqlw.getNextWarning()) != null) {
			    Debug.println("next SQLWarning is "+ sqlw);
			  }
			}
			Debug.println(""+rs_sum);
		    }}}
		    valid_date.addHours(12);
	    }
	} catch(Exception e) {
	    Debug.println("Exception: "+e);
	    e.printStackTrace();
	} finally {
	    try {
		if(con_sum != null) {
		    con_sum.close();
		}
	    } catch(SQLException e) {
		Debug.println("SQL Exception: "+e.getMessage());
		System.exit(1);
	    }
	}

    }
}
  
