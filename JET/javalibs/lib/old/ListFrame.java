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
import java.awt.Toolkit.*;

public class ListFrame extends Frame
   implements MyButtonListener {
  List li;
  String frame_title;
  String action_label;
  int n_showing;		// number of items in list showing
  boolean multiple;		// true if can chose multiple items
  int x,y;			// initial location on screen
  MyButton action_btn;
  MyButton apply_btn;
  Font f;
  FrameParent p;
  boolean action = false;
  boolean closed = false;
   
public ListFrame(FrameParent p, Font f,
		 String frame_title, List li, String action_label,
		 int x, int y) {
  super(frame_title);
  this.f = f;
  this.li = li;
  this.p = p;
  this.x = x;
  this.y = y;
  setFont(f);
  
  // handle window closing
  addWindowListener(new WindowAdapter() {
     public void windowClosing(WindowEvent e) {
       Debug.println("ListFrame caught close event");
       closed=true;
       action=false;
       ListFrame.this.p.frameAction(ListFrame.this,action,closed);
     }});

  // lay it out
  setLayout(new GridBagLayout());

  // THE TITLE
  Label lab = new Label(frame_title,Label.CENTER);
  MyUtil.addComponent(this,lab,0,0,1,1,0,0);

  // THE LIST
  MyUtil.addComponent(this,li,0,1,1,1,1,1,5,5,5,5);

  // ACTIONS
  Panel pSouth = new Panel();
  pSouth.setLayout(new FlowLayout());
  action_btn = new MyButton(f," "+action_label+"   ",false);
  action_btn.addListener(this);
  pSouth.add(action_btn);

  apply_btn = new MyButton(f," Apply  ",false);
  apply_btn.addListener(this);
  pSouth.add(apply_btn);

  //add(BorderLayout.SOUTH,pSouth);
  MyUtil.addComponent(this,pSouth,0,2,1,1,0,0);
  
  pack();
  setLocation(x,y);
}

public void myAction(MyButton b) {
  if(b == apply_btn) {
    // post a window closing event
    // Damn.  Security manager won't let me do it.
    //Toolkit.getDefaultToolkit().
    //  getSystemEventQueue().
    //  postEvent(new WindowEvent(this,WindowEvent.WINDOW_CLOSING));
    action = true;
    closed = false;
  } else {
    action=true;
    closed=true;
  }
  p.frameAction(this,action,closed);
}

}
