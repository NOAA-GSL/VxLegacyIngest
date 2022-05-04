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

/**
 * A frame that holds a list
 * history
 * 25-May-04 - added 'all_none' argument which, if true, causes two
 *             buttons to appear below the list: 'Select all' and 'Clear'
 *             (This functionality obviates the need for the
 *             AllSelectableList class, which is now deprecated.)
 */
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
  MyButton all_btn = null;
  MyButton clear_btn = null;
  Font f;
  FrameParent p;
  boolean action = false;
  boolean closed = false;
  boolean all_none = false;

public ListFrame(FrameParent p, Font f,
		 String frame_title, List li, String action_label,
		 int x, int y) {
  this(p,f,frame_title,li,action_label,x,y,false);
}
  
public ListFrame(FrameParent p, Font f,
		 String frame_title, List li, String action_label,
		 int x, int y, boolean all_none) {
  super(frame_title);
  this.f = f;
  this.li = li;
  this.p = p;
  this.x = x;
  this.y = y;
  this.all_none = all_none;
  setFont(f);
  if(all_none &&
     ! li.isMultipleMode()) {
    System.err.println("ERROR: ListFrame called with all_none, but "+
		       "list does not allow multiple selection!");
  }
  
  // handle window closing
  addWindowListener(new WindowAdapter() {
     public void windowClosing(WindowEvent e) {
       Debug.println("ListFrame caught close event");
       closed=true;
       action=false;
       ListFrame.this.p.frameAction(ListFrame.this,action,closed);
     }});

  // lay it out
  int row = 0;
  setLayout(new GridBagLayout());

  // THE TITLE
  Label lab = new Label(frame_title,Label.CENTER);
  MyUtil.addComponent(this,lab,0,row++,1,1,0,0);

  // THE LIST
  MyUtil.addComponent(this,li,0,row++,1,1,1,1,5,5,5,5);

  // ACTIONS
  if(all_none) {
    // add 'select all' and 'clear' buttons
    Panel p2 = new Panel();
    p2.setLayout(new FlowLayout());
    all_btn = new MyButton(f," Select all ",false);
    all_btn.addListener(this);
    p2.add(all_btn);
    clear_btn = new MyButton(f," Clear ",false);
    clear_btn.addListener(this);
    p2.add(clear_btn);
    MyUtil.addComponent(this,p2,0,row++,1,1,0,0,0,0,0,0);
  }
  
  Panel pSouth = new Panel();
  pSouth.setLayout(new FlowLayout());
  action_btn = new MyButton(f," "+action_label+"   ",false);
  action_btn.addListener(this);
  pSouth.add(action_btn);

  apply_btn = new MyButton(f," Apply  ",false);
  apply_btn.addListener(this);
  pSouth.add(apply_btn);

  //add(BorderLayout.SOUTH,pSouth);
  MyUtil.addComponent(this,pSouth,0,row++,1,1,0,0,0,0,0,0);
  
  pack();
  setLocation(x,y);
}

public void myAction(MyButton b) {
  if(b == all_btn || b == clear_btn) {
    for(int i=0;i<li.getItemCount();i++) {
      if(b == all_btn) {
	li.deselect(i);		// needed for linux, apparently
	li.select(i);
      } else {
	li.deselect(i);
      }
    }
  } else {
    if(b == apply_btn) {
      action = true;
      closed = false;
    } else if(b == action_btn){
      action=true;
      closed=true;
    }
    p.frameAction(this,action,closed);
  }
}

}
