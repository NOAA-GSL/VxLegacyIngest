import lib.*;
import java.util.*;
import java.io.*;
// set CLASSPATH to "/misc/whome/moninger/mysql-connector-java-5.1.6/mysql-connector-java-5.1.6-bin.jar:."
import java.sql.*;

public class GetBias {

public static void main(String [ ] args) {
  GetBias gb = new GetBias();
  gb.process_data();
}

public void process_data() {
  Debug.DEBUG = true;
  Debug.STDIO = true;		// send to stdout, not stderr
  if(false) {
    Map<String, String> variables = System.getenv();  
    for (Map.Entry<String, String> entry : variables.entrySet())  {  
      String name = entry.getKey();  
      String value = entry.getValue();  
      Debug.println(name + "=" + value);  
    }
  }
  String db_url = "jdbc:mysql://wolphin/acars_RR";
  Connection con = null;
  try {
    Class.forName("com.mysql.jdbc.Driver").newInstance();
    con = DriverManager.getConnection(db_url,"wcron0_user","cohen_lee");
    if(!con.isClosed()) {
      Debug.println("connected to MySQLserver");
    }
    Statement stmt = con.createStatement();
    Statement update_stmt = con.createStatement();
    int last_xid = -1;
    int last_mb = -1;
    Hashtable xid_data = new Hashtable();
    ResultSet rs =
      stmt.executeQuery("select * from T_bias2 order by xid,mb,secs");
    while(rs.next()) {
      int xid = rs.getInt("xid");
      int secs = rs.getInt("secs");
      int mb = rs.getInt("mb");
      double t_omb = rs.getDouble("T_OMB");
      int N_for_week = rs.getInt("N");
      if((xid != last_xid || mb != last_mb) &&
	 (last_xid != -1 && last_mb != -1)) {
	//Debug.println("finished "+last_xid+" at "+last_mb+" mb");
	// process it here
	process_xid(update_stmt,xid_data,last_xid,last_mb);
	// prepare for new xid
	xid_data.clear();
      }
      last_xid = xid;
      last_mb = mb;	 
      BiasData bd = new BiasData(xid,secs,mb,t_omb,N_for_week);
      xid_data.put(new Integer(secs),bd);
    }
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

public void process_xid(Statement update_stmt, Hashtable xid_data,int xid,int mb) throws SQLException {
  int[] all_secs = {1339372800 , 1339977600 , 1340582400 , 1341187200 , 1341792000 , 1342396800 ,
		1343001600 , 1343606400 , 1344211200 , 1344816000 , 1345420800 , 1346025600 , 1346630400 ,
		1347235200 , 1347840000 , 1348444800 , 1349049600 , 1349654400 , 1350259200 , 1350864000 ,
		1351468800 , 1352073600 , 1352678400 , 1353283200 , 1353888000 , 1354492800 , 1355097600 ,
		1355702400 , 1356307200 , 1356912000 , 1357516800 , 1358121600 , 1358726400 , 1359331200};
  double[] data = new double[all_secs.length];
  int Nobs = 0;
  for(int i=0;i<all_secs.length;i++) {
    int sec = all_secs[i];
    BiasData bd = (BiasData)xid_data.get(new Integer(sec));
    if(bd == null) {
      data[i] = Double.NaN;
    } else {
      data[i] = bd.t_omb;
      Nobs += bd.N;
    }
    //Debug.println(""+sec+": "+bd);
  }
  double[] stats = Stat.getStdErr(data);
  String stat_info = String.format("%d %d: mean %.3f, std err %.3f, Nweeks %.0f, Nobs %d sd %.3f, lag1 %.3f",
				   xid,mb,stats[0],stats[1],stats[3],Nobs,stats[2],stats[4]);
  Debug.println(stat_info);
  String upd = String.format("replace into T_stdE values(%d,%d,%f,%s,%.0f,%d,%f,%s)",
			     xid,mb,stats[0],get_null(stats[1]),stats[3],Nobs,stats[2],get_null(stats[4]));
  Debug.println(upd);
  update_stmt.executeUpdate(upd);
}

public String get_null(double val) {
  String result = "\\N";
  if(!Double.isNaN(val)) {
    result = String.format("%f",val);
  }
  return(result);
}
  
}
