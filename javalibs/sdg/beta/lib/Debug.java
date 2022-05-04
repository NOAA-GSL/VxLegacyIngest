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
/**
* optionally prints out data if flag DEBUG is true
* @version 1.0  19-Jun-1997
* @author Bill Moninger, NOAA, Forecast Systems Laboratory
*/
public final class Debug {
    public static boolean DEBUG = false;

/**
* @param string The message to print if DEBUG is true
*/
public static void println(String string) {
    if(DEBUG) {
        System.err.println(string);
    }
}

/**
* @param string The message to print if DEBUG is true
*/
public static void print(String string) {
    if(DEBUG) {
        System.err.print(string);
    }
}

} //end of class Debug
