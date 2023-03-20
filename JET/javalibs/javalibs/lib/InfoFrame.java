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

import java.awt.*;
import java.awt.event.*;
import java.util.*;

/**
* Provides a Frame for information
*
* revision history
* 25-May-04  Added max_chars as an input argument
*            Corrected a bug in method disposeAll
*
*/

public class InfoFrame extends Frame {
  static Vector infoFrames = new Vector();
  
  String info;
  StringBuffer out_info;
  int max_chars;  //max number of chars per line
  int max_lines;
  Font f;
  FontMetrics fm;
  

  /**
   * Use default font and specify location
   */
public InfoFrame(String info, int max_width_px,int max_height_px,
		 int loc_x, int loc_y) {
  this(info,max_width_px,max_height_px,
       new Font("Helvetica",Font.PLAIN,12));
  setLocation(loc_x,loc_y);
}

  /**
   * Use default font
   */
public InfoFrame(String info, int max_width_px,int max_height_px) {
  this(info,max_width_px,max_height_px,
       new Font("Helvetica",Font.PLAIN,12));
}

  /**
   * Use provided font and set location
   */
public InfoFrame(String _info,
                 int max_width_px, int max_height_px, Font _f,
		 int loc_x, int loc_y) {
  this(_info,max_width_px,max_height_px,_f);
  setLocation(loc_x,loc_y);
}
  
  /**
   * Use provided font
   */
public InfoFrame(String _info,
                 int max_width_px, int max_height_px,
		 Font _f) {
  this(_info,max_width_px,max_height_px,_f,75);
}
  
  /**
   * Use provided font
   */
public InfoFrame(String _info,
                 int max_width_px, int max_height_px, Font _f,
		 int max_chars) {
  this.max_chars = max_chars;
  Debug.println("max chars set to "+max_chars);
  info = _info.trim()+"\n";
  out_info = new StringBuffer("");
  f = _f;
  
  // some of the font and layout stuff doesn't work for netscape, so
  // hardwire for now
  max_lines = 40;
  int max_index = info.length();
  int max_title = Math.min(max_index,20);
  int end_index = Math.min(max_index,max_chars);
  
  //Debug.println("2 parsing infoframe with "+max_index);
  //Debug.println(" "+max_title);
  setTitle(info.substring(0,max_title));
  setLayout(new GridBagLayout());
   //change some spaces to newlines
  boolean done = false;
  int start_index = 0;
  int break_index = -1;
  int newline_index = -1;
  int n_lines=0;
  //Debug.println(info);
  //Debug.println("length of string is "+max_index);
  boolean find_first = false;

  //loop (almost) forever if we don't break out
  for (int i =0;i<max_index+10;i++) {
    //Debug.println("Loop "+i+" start: "+start_index+", end: "+end_index
    //	  +" "+find_first);
    if(start_index < 0 || end_index < 0) {
      Debug.println("bad start index in Infoframe 1");
      end_index=max_chars;
      //Debug.println("|"+info.substring(0,end_index)+"|");
    }
    
    if(start_index >= max_index) {
      break;
    }
    /* if(end_index >= max_index) {
       out_info.append( info.substring(start_index,max_index));
       n_lines++;
       break;
       } */
    //respect any newlines already in the string
    if(start_index < 0 || end_index < 0) {
      Debug.println("bad start index in Infoframe 2");
      start_index=0;
      end_index=max_chars;
    }
    //Debug.println(start_index+" 2 "+end_index);
    //Debug.println("looking at |"+info.substring(start_index,end_index)+"|");
    newline_index = info.substring(start_index,end_index).indexOf("\n");
    if(newline_index != -1) {
      newline_index += start_index;
    }
    //Debug.println("newline_index: "+newline_index);
    if(newline_index == -1) {
      //found no newline.  Look for a space to put one if we need to
      if(find_first) {
	if(start_index < 0 || end_index < 0) {
	  Debug.println("bad start index in Infoframe 3");
	  start_index=0;
	  end_index=max_chars;
	}
	//Debug.println(start_index+" 3 "+end_index);
	break_index = info.substring(start_index,end_index).indexOf(" ");
	if(break_index != -1) {
	  break_index += start_index;
	}
	//Debug.println("break_index: "+break_index);
      } else {
	break_index = info.substring(start_index,end_index).lastIndexOf(" ");
	if(break_index != -1) {
	  break_index += start_index;
	  }
      }
    }
    if(newline_index != -1) {
	if(start_index < 0 || newline_index < -1) {
	  Debug.println("bad start index in Infoframe 4");
	  start_index=0;
	  newline_index=max_chars-1;
	}
        out_info.append(info.substring(start_index,newline_index+1));
	//Debug.println("line "+n_lines+" "+start_index+" to "+newline_index);
        n_lines++;
        find_first = false;
        start_index = newline_index+1;
    } else if(break_index != -1) {
        //we found a place to break
        //Debug.println("breaking line.  break index="+break_index);
	if(start_index < 0 || break_index < 0) {
	  Debug.println("bad start index in Infoframe 5");
	  start_index=0;
	  break_index=max_chars;
	}
        out_info.append(info.substring(start_index,break_index) + "\n");
        n_lines++;
        find_first = false;
        start_index = break_index + 1;
    } else {
        //no space was found.  put everything out
      	if(start_index < 0 || end_index < 0) {
	  Debug.println("bad start index in Infoframe 6");
	  start_index=0;
	  end_index=max_chars;
	}
        out_info.append(info.substring(start_index,end_index));
        n_lines++;
        //but break the line as soon as possible
	//Debug.println("setting find_first");
        find_first=true;
        start_index = end_index;
    }
    end_index = start_index + max_chars;
    //Debug.println(i+": "+start_index+" "+end_index);
    if(end_index > max_index) {
        end_index = max_index;
    }
    //Debug.println("|"+info.substring(start_index,end_index)+"|\n");
  }
  //Debug.println("Finished breaking the line");

  n_lines += 2;
  //Debug.println("n_lines = "+n_lines);
  n_lines = Math.min(max_lines,n_lines);
  String out_string = ""+out_info;
  TextArea msg = new TextArea(out_string,n_lines,max_chars+1);
  msg.setEditable(false);
  msg.setFont(f);
  MyUtil.addComponent(this,msg,0,0,1,1,1,1,0,0,0,0);
  pack();
  
  // handle window closing
  addWindowListener(new WindowAdapter() {
    public void windowClosing(WindowEvent e) {
      dispose();
    }});

  // update the static vector of infoframes
  infoFrames.addElement(this);
}

public static void disposeAll() {
  while(infoFrames.size() > 0) {
    InfoFrame inf = (InfoFrame) infoFrames.elementAt(0);
    inf.dispose();
    infoFrames.removeElementAt(0);
  }
}


} //end of class InfoFrame
