import lib.*;
import java.util.*;
import java.io.*;
import java.sql.*;
		 
public class DealWithResids {
  Connection con_resids = null;
  Statement stmt = null;
  String query = "";
  int wmoid;
  String name;
  String descript;
  double mx_t_dif = 0;	  // max T resid of raob with worst T resid
  double mx_ws_dif = 0;	  // max wind speed resid of raob with worst wind speed resid
  double mx_dp_dif = 0;	  // max dew point resid of raob with worst dew point resid
  double mx_z_dif = 0;	  // max height resid of raob with worst height resid
  double mx_dif = 0;
  double avg_t_dif  = 0;	  // average over all RAOBs in domain of max T resids of each RAOB
  double avg_ws_dif = 0;	  // average over all RAOBs in domain of max wind speed resids of each RAOB
  double avg_dp_dif = 0;	  // average over all RAOBs in domain of max dew point resids of each RAOB
  double avg_z_dif = 0;	  // average over all RAOBs in domain of max height resids of each RAOB
  static final double mx_t_lim = 80; // max allowed mx_t_dif, in degree C
  static final double mx_ws_lim = 60; // max allowed mx_ws_dif, in m/s
  static final double mx_dp_lim = 1500; // max allowed mx_dp_dif, in degree C (turned off for now)
  static final double mx_z_lim = 1500; // max allowed mx_z_dif, in m (this value DOES find some bad RAOBs)
  static final double avg_t_lim = 10; // max allowed_avg_t_dif in degree C
  static final double avg_ws_lim = 20; // max allowed avg_ws_dif, in m/s
  static final double avg_dp_lim = 1000; // max allowed avg_dp_dif, in degree C (turned off for now)
  static final double avg_z_lim = 1000; // max allowed avg_z_dif, in m
  Vector t_raob_resids;
  Vector ws_raob_resids;
  Vector dp_raob_resids;
  Vector z_raob_resids;
  String resids_table;
  String model;
  UTCDate valid_date;
  int fcst_len;
  boolean mail_report = false;
  StringBuffer sb = null;
  String recipients = "verif-amb.gsd@noaa.gov";
  boolean bad_model = false;
  boolean bad_t_raob=false;
  boolean bad_ws_raob=false;
  boolean bad_dp_raob=false;
  boolean bad_z_raob=false;

	       
public DealWithResids(String model,UTCDate valid_date, int fcst_len)
  throws SQLException {
   this.model = model;
   this.valid_date = valid_date;
   this.fcst_len = fcst_len;
   String field_list = "valid_time,fcst_len,avg_t_dif,avg_ws_dif,mx_t_dif,t_wmoid,mx_ws_dif,ws_wmoid";
   boolean has_heights = false;
   // if needed
   sb = new StringBuffer(
			 "To: "+recipients+"\n"+
			 "From: WARNINGS_jet\n"+
			 "Reply-to: "+recipients+"\n"+
			 "Subject: WARNING: large residuals\n\n"+
			 "From ~amb-verif/ruc_uaverif/update_all_sums.pl (DealWithResids.java)\n"+
			 "for "+fcst_len+" h fcst from "+model+"\n");
    
   con_resids = DriverManager.getConnection("jdbc:mysql://wolphin.fsl.noaa.gov/ruc_ua",
					    "wcron0_user","cohen_lee");
   if(!con_resids.isClosed()) {
     //System.out.println("connected to ruc_ua on MySQLserver");
   } else {
     Debug.println("PROBLEM connecting to ruc_ua!");
   }

  // for now, only do this if a resids table exists
   resids_table = model+"_resids";
   stmt = con_resids.createStatement();
   ResultSet res_ck = stmt.executeQuery("show tables like \""+resids_table+"\"");
   if(res_ck.next()) {
     // resids table exists. proceed
     // see if it has heights (and dewpoints)
     Statement stmt_sum = con_resids.createStatement();
     ResultSet rsd = stmt_sum.executeQuery("describe "+resids_table);
    while(rsd.next()) {
       String fname = rsd.getString("Field");
       if(fname.equals("z_wmoid")) {
	 has_heights = true;
	 field_list += ",avg_dp_dif,avg_z_dif,mx_dp_dif,dp_wmoid,mx_z_dif,z_wmoid";
       }
    }
   
    String tmp_table = "max_difs";
    query =
"create temporary table "+tmp_table+"\n"+
"select RAOB.wmoid\n"+
",n.name as name\n"+
",n.descript as descript\n"+
",max(abs(RAOB.t - "+model+".t)/100) as mx_t_dif\n"+
",max(abs(RAOB.ws - "+model+".ws)/100) as mx_ws_dif\n"+
",max(abs(RAOB.dp - "+model+".dp)/100) as mx_dp_dif\n"+
",max(abs(RAOB.z - "+model+".z)) as mx_z_dif\n"+
"from RAOB,"+model+",metadata as n\n"+
"where 1=1\n"+
"and RAOB.wmoid = n.wmoid\n"+
"and RAOB.wmoid = "+model+".wmoid\n"+
"and RAOB.date = "+model+".date\n"+
"and RAOB.hour = "+model+".hour\n"+
"and RAOB.press = "+model+".press\n"+
      "and RAOB.date = '"+valid_date.getSQLDate()+"'\n"+
      "and RAOB.hour = "+valid_date.getHour()+"\n"+
"and "+model+".fcst_len = "+fcst_len+"\n"+
"group by RAOB.wmoid\n";

    //Debug.println(query);
    stmt.execute(query);

  query =
"select wmoid,name,descript,mx_t_dif\n"+
"from "+tmp_table+"\n"+
"order by mx_t_dif desc\n";
  ResultSet resid = stmt.executeQuery(query);
  t_raob_resids = new Vector();
  boolean no_data=true;
  while(resid.next()) {
    no_data = false;
    wmoid = resid.getInt("wmoid");
    name = resid.getString("name");
    descript = resid.getString("descript");
    mx_dif = resid.getDouble("mx_t_dif");
    RaobResid rr = new RaobResid(wmoid,name,descript,mx_dif);
    System.out.println("t_resid: "+rr);
    t_raob_resids.add(rr);
    if(mx_dif < mx_t_lim) {
      break;
    } else {
      bad_t_raob=true;
    }
  }

  // make sure we don't have a missing model
  if(no_data) {
    Debug.println("NO DATA FOR THIS VALID TIME AND FORECAST.");
  } else {
    
  query =
"select wmoid,name,descript,mx_ws_dif\n"+
"from "+tmp_table+"\n"+
"order by mx_ws_dif desc\n";
  resid = stmt.executeQuery(query);
  ws_raob_resids = new Vector();
  while(resid.next()) {
    wmoid = resid.getInt("wmoid");
    name = resid.getString("name");
    descript = resid.getString("descript");
    mx_dif = resid.getDouble("mx_ws_dif");
    RaobResid rr = new RaobResid(wmoid,name,descript,mx_dif);
    System.out.println("ws_resid: "+rr);
    ws_raob_resids.add(rr);
    if(mx_dif < mx_ws_lim) {
      break;
    } else {
      bad_ws_raob=true;
    }
  }
    
  query =
"select wmoid,name,descript,mx_dp_dif\n"+
"from "+tmp_table+"\n"+
"order by mx_dp_dif desc\n";
  resid = stmt.executeQuery(query);
  dp_raob_resids = new Vector();
  while(resid.next()) {
    wmoid = resid.getInt("wmoid");
    name = resid.getString("name");
    descript = resid.getString("descript");
    mx_dif = resid.getDouble("mx_dp_dif");
    RaobResid rr = new RaobResid(wmoid,name,descript,mx_dif);
    System.out.println("dp_resid: "+rr);
    dp_raob_resids.add(rr);
    if(mx_dif < mx_dp_lim) {
      break;
    } else {
      bad_dp_raob=true;
    }
  }
    
  query =
"select wmoid,name,descript,mx_z_dif\n"+
"from "+tmp_table+"\n"+
"order by mx_z_dif desc\n";
  resid = stmt.executeQuery(query);
  z_raob_resids = new Vector();
  while(resid.next()) {
    wmoid = resid.getInt("wmoid");
    name = resid.getString("name");
    descript = resid.getString("descript");
    mx_dif = resid.getDouble("mx_z_dif");
    RaobResid rr = new RaobResid(wmoid,name,descript,mx_dif);
    System.out.println("z_resid: "+rr);
    z_raob_resids.add(rr);
    if(mx_dif < mx_z_lim) {
      break;
    } else {
      bad_z_raob=true;
    }
  }
  
  query = "select "+
    "avg(mx_t_dif) as avg_t_dif"+
    ",avg(mx_ws_dif) as avg_ws_dif"+
    ",avg(mx_dp_dif) as avg_dp_dif"+
    ",avg(mx_z_dif) as avg_z_dif"+
    " from "+tmp_table;
  resid = stmt.executeQuery(query);
  if(resid.first()) {
    avg_t_dif = resid.getDouble("avg_t_dif");
    avg_ws_dif = resid.getDouble("avg_ws_dif");
    avg_dp_dif = resid.getDouble("avg_dp_dif");
    avg_z_dif = resid.getDouble("avg_z_dif");
    Debug.println("avg_t_dif: "+avg_t_dif+", avg_ws_dif: "+avg_ws_dif+
		  ", avg_dp_dif: "+avg_dp_dif+", avg_z_dif: "+avg_z_dif);
  }
  
  RaobResid t_rr = (RaobResid)t_raob_resids.firstElement();
  RaobResid ws_rr = (RaobResid)ws_raob_resids.firstElement();
  RaobResid dp_rr = (RaobResid)dp_raob_resids.firstElement();
  RaobResid z_rr = (RaobResid)z_raob_resids.firstElement();
  if(avg_t_dif != 0 && avg_ws_dif != 0 && t_rr.resid != 0 && ws_rr.resid != 0 &&
       t_rr.wmoid != 0 && ws_rr.wmoid != 0) {
      query = "insert ignore into "+resids_table+"("+field_list+") "+
	" VALUES("+valid_date.get1970Secs()+","+fcst_len+","+avg_t_dif+","+avg_ws_dif+","+t_rr.resid+","+
	t_rr.wmoid+","+ws_rr.resid+","+ws_rr.wmoid;
      if(has_heights) {
	query += ","+avg_dp_dif+","+avg_z_dif+","+dp_rr.resid+","+dp_rr.wmoid+","+z_rr.resid+","+z_rr.wmoid;
      }
      query += ")";
      Debug.println("from DealWithResids: "+query);
      stmt.execute(query);
      SQLWarning sqlw = stmt.getWarnings();
      if(sqlw != null) {
	Debug.println("SQLWarning is "+ sqlw);
	while((sqlw = sqlw.getNextWarning()) != null) {
	  Debug.println("next SQLWarning is "+ sqlw);
	}
      }

     report_bad_model();
     remove_bad_raobs();
     //Debug.println(sb.toString());
     mail_bad();
   }
  }
   }
}

public void mail_bad() {
  /* DON'T send email for bad Z raobs, because there are so many of them
   */
  if(bad_model || bad_t_raob || bad_ws_raob || bad_dp_raob) {
    try {
      // put string buffer to a file
      File tmpDir = new File("tmp/");
      File tmp_file = File.createTempFile("mail_file.",".tmp",tmpDir);
      FileWriter fw = new FileWriter(tmp_file);
      fw.write(sb.toString());
      fw.close();
      Debug.println(sb.toString());
      String[] cmd = {
	"/bin/sh", "-c",
	"/usr/sbin/sendmail -t < "+tmp_file};
      Process p = Runtime.getRuntime().exec(cmd);
    } catch(IOException e) {
      Debug.println("exception: "+e);
    }
  }
}
						 
public void report_bad_model() {
  if(avg_t_dif > avg_t_lim ||
     avg_ws_dif > avg_ws_lim ||
     avg_dp_dif > avg_dp_lim ||
     avg_z_dif > avg_z_lim) {
    bad_model = true;
    sb.append(
"Possible bad model results for "+model+" "+fcst_len+"h forecast valid "+valid_date.getSQLDateTime()+"\n"+
"average max T difference for all RAOBs is "+avg_t_dif+"\n"+
"average max ws difference for all RAOBs is "+avg_ws_dif+"\n"+
"average max dp difference for all RAOBs is "+avg_dp_dif+"\n"+
"average max z difference for all RAOBs is "+avg_z_dif+"\n"+
"PLEASE CHECK THIS MODEL RUN\n\n");
  }
}

public void remove_bad_raobs() {
  if(bad_model) {
    return;
  }
  try{
    if(bad_t_raob) {
      // one or more apparent bad RAOB(s) for t, but not a bad model run
      // need to remove the last element of the vector because it's resid is below the limit
      t_raob_resids.remove(t_raob_resids.lastElement());
      Enumeration t_raobs = t_raob_resids.elements();
      while(t_raobs.hasMoreElements()) {
	RaobResid rr = (RaobResid)t_raobs.nextElement();
	String query =
	  "update RAOB \n"+
	  "set t = null \n"+
	  "where wmoid = "+rr.wmoid+"\n"+
	  "and date = '"+valid_date.getSQLDate()+"'\n"+
	  "and hour = "+valid_date.getHour();
	Debug.println(query);
	int rows = stmt.executeUpdate(query);
	Debug.println(rows+" rows updated");
      }
    }
    if(bad_ws_raob) {
      // one or more apparent bad RAOB(s) for ws, but not a bad model run
      // need to remove the last element of the vector because it's resid is below the limit
      ws_raob_resids.remove(ws_raob_resids.lastElement());
      Enumeration ws_raobs = ws_raob_resids.elements();
      while(ws_raobs.hasMoreElements()) {
	RaobResid rr = (RaobResid)ws_raobs.nextElement();
	String query =
	  "update RAOB \n"+
	  "set ws = null, wd = null \n"+
	  "where wmoid = "+rr.wmoid+"\n"+
	  "and date = '"+valid_date.getSQLDate()+"'\n"+
	  "and hour = "+valid_date.getHour();
	Debug.println(query);
	int rows = stmt.executeUpdate(query);
	Debug.println(rows+" rows updated");
      }
    }
    if(bad_dp_raob) {
      // one or more apparent bad RAOB(s) for dp, but not a bad model run
      // need to remove the last element of the vector because it's resid is below the limit
      dp_raob_resids.remove(dp_raob_resids.lastElement());
      Enumeration dp_raobs = dp_raob_resids.elements();
      while(dp_raobs.hasMoreElements()) {
	RaobResid rr = (RaobResid)dp_raobs.nextElement();
	String query =
	  "update RAOB \n"+
	  "set dp = null, rh = null \n"+
	  "where wmoid = "+rr.wmoid+"\n"+
	  "and date = '"+valid_date.getSQLDate()+"'\n"+
	  "and hour = "+valid_date.getHour();
	Debug.println(query);
	int rows = stmt.executeUpdate(query);
	Debug.println(rows+" rows updated");
      }
    }
    if(bad_z_raob) {
      // one or more apparent bad RAOB(s) for z, but not a bad model run
      // need to remove the last element of the vector because it's resid is below the limit
      z_raob_resids.remove(z_raob_resids.lastElement());
      Enumeration z_raobs = z_raob_resids.elements();
      while(z_raobs.hasMoreElements()) {
	RaobResid rr = (RaobResid)z_raobs.nextElement();
	String query =
	  "update RAOB \n"+
	  "set z = null \n"+
	  "where wmoid = "+rr.wmoid+"\n"+
	  "and date = '"+valid_date.getSQLDate()+"'\n"+
	  "and hour = "+valid_date.getHour();
	Debug.println(query);
	int rows = stmt.executeUpdate(query);
	Debug.println(rows+" rows updated");
      }
    }
    //report
    /* but DON'T report bad Z raobs, because we always have them
     */
    if(bad_t_raob || bad_ws_raob || bad_dp_raob) {
     sb.append("Possibly bad RAOB(s) for "+valid_date.getSQLDateTime()+" have been updated.\n");
     if(bad_t_raob) {
       Enumeration t_raobs = t_raob_resids.elements();
       while(t_raobs.hasMoreElements()) {
	 RaobResid rr = (RaobResid)t_raobs.nextElement();
	 sb.append(rr+"C was updated to remove bad t\n");
       }
     }
     if(bad_ws_raob) {
       Enumeration ws_raobs = ws_raob_resids.elements();
       while(ws_raobs.hasMoreElements()) {
	 RaobResid rr = (RaobResid)ws_raobs.nextElement();
	 sb.append(rr+"m/s was updated to remove bad ws (and wd)\n");
       }
     }
     if(bad_dp_raob) {
       Enumeration dp_raobs = dp_raob_resids.elements();
       while(dp_raobs.hasMoreElements()) {
	 RaobResid rr = (RaobResid)dp_raobs.nextElement();
	 sb.append(rr+"C was updated to remove bad dp (and rh)\n");
       }
     }
     /*
     if(bad_z_raob) {
       Enumeration z_raobs = z_raob_resids.elements();
       while(z_raobs.hasMoreElements()) {
	 RaobResid rr = (RaobResid)z_raobs.nextElement();
	 sb.append(rr+"m was updated to remove bad heights\n");
       }
     }
     */
   }
  } catch(SQLException e) {
    Debug.println("SQLException "+e);
  }
}

private class RaobResid {
  int wmoid;
  String name;
  String descript;
  double resid;

private RaobResid(int wmoid,String name,String descript,double resid) {
  this.wmoid = wmoid;
  this.name = name;
  this.descript = descript;
  this.resid = resid;
}

public String toString() {
  return(wmoid+" ("+name+", "+descript+") with max resid "+resid);
}
}
  
}

  
