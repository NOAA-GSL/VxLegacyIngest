/*
Open Source License/Disclaimer, 
Forecast Systems Laboratory
NOAA/OAR/FSL
325 Broadway Boulder, CO 80305 

This software is distributed under the Open Source Definition, which
may be found at http://www.opensource.org/osd.html. In particular,
redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:  
<ul>
<li> Redistributions of source code must retain this notice, this list of
  conditions and the following disclaimer. 

<li> Redistributions in binary form must provide access to this notice,
  this list of conditions and the  following disclaimer, and the
  underlying source code.
  
<li> All modifications to this software must be clearly documented, and
  are solely the responsibility of the agent making the
  modifications.
  
<li> If significant modifications or enhancements are made to this
  software, the Forecast Systems Laboratory should be notified.
</ul>
    
THIS SOFTWARE AND ITS DOCUMENTATION ARE IN THE PUBLIC DOMAIN AND ARE
FURNISHED "AS IS." THE AUTHORS, THE UNITED STATES GOVERNMENT, ITS
INSTRUMENTALITIES, OFFICERS, EMPLOYEES, AND AGENTS MAKE NO WARRANTY,
EXPRESS OR IMPLIED, AS TO THE USEFULNESS OF THE SOFTWARE AND
DOCUMENTATION FOR ANY PURPOSE. THEY ASSUME NO RESPONSIBILITY (1) FOR THE
USE OF THE SOFTWARE AND DOCUMENTATION; OR (2) TO PROVIDE TECHNICAL
SUPPORT TO USERS. 
*/
package lib;

import java.net.*;

public class Logger extends Thread {
    static int n_entries=0;

    URL code_base;
    String log_file;
    String args;

   public Logger(URL code_base,String log_file, String args) {
    this.code_base=code_base;
    this.log_file=log_file;
    this.args = args;

    this.start();
   }

///////////////////////////////////////////////////////////////
  public void run() {
    setPriority(Thread.MIN_PRIORITY);
    //Debug.println("Into logger");
    log_item();
  }  //end of method run

///////////////////////////////////////////////////////////////
public void log_item() {
    String log_file_get=null;
    //log this access
     long t1 = System.currentTimeMillis();
      String Version="";
      try {
	    Version = new String(System.getProperty("os.name")+ " " +
			     System.getProperty("os.version"));
        if(log_file != null &&
	       (Version.indexOf("OS/2") == -1)) {
            log_file_get= log_file+"?"+args+"&n_entries="+n_entries;
            n_entries++;
            URL logURL = new URL(code_base,log_file_get);
            Debug.println("Log info to "+logURL);
            URLConnection loguc = logURL.openConnection();
            loguc.connect();
            String status = loguc.getHeaderField("Status"); //force a cgi call in IE
            //Debug.println("Status is "+status);
       }
      } catch (Exception e) {
        Debug.println("trouble writing log file: "+e);
      }
    long t2 = System.currentTimeMillis();
    long t21 = t2 - t1;
    //Debug.println("Time send to log file = "+t21+" milliseconds");
}

}
