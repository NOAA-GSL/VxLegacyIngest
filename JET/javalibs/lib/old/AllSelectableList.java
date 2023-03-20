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

/**
 * Implements a List with two extra items at the top:
 *  "All" and "Clear List"
 * clicking these two selects or deselects everything else in
 * the list, respectively.
 */

public class AllSelectableList extends List
  implements ItemListener {

  int width,height;

public AllSelectableList(int n_showing) {
  super(n_showing+2,true);
  add("Select all");
  add("Clear list");
  addItemListener(this);
}

public void removeAll() {
  super.removeAll();
  add("Select all");
  add("Clear list");
}

public void selectAll() {
  select(0);
  for(int i = 0;i<getItemCount();i++) {
    select(i);
  }
}

public int getItemCount() {
  return super.getItemCount()-2;
}

  /*
public String getItem(int i) {
  String result="";
  try {
    result = super.getItem(i+2);
  } catch(Exception e) {Debug.println("exception "+e+" with i = "+i);}
  return result;
}
  */
  
public void add(String s, int i) {
  super.add(s,i+2);
}

public void select(int i) {
  super.select(i+2);
}

public void deselect(int i) {
  super.deselect(i+2);
}

public boolean isIndexSelected(int i) {
  return super.isIndexSelected(i+2);
}

public boolean isSelected(String s) {
  String[] ss = getSelectedItems();
  boolean result = false;
  if(ss != null) {
    for(int i=0;i<ss.length;i++) {
      if(ss[i].equals(s)) {
	result = true;
	break;
      }
    }
  }
  return result;
}

public void select(String s) {
  String[] ss = super.getItems();
  // i is the internal index, which includes the 'All' and 'clear' items
  for(int i=0;i<ss.length;i++) {
    if(ss[i].equals(s)) {
      super.select(i);
      break;
    }
  }
}
 
public String[] getSelectedItems() {
  String[] s2 = null;
  String[] s1 = super.getSelectedItems();
  if(super.isIndexSelected(1)) {
    // "Clear list" was selected
  } else if(super.isIndexSelected(0)) {
    // "Select all" was selected.
    // if that's the only thing selected, return null
    if(s1.length > 1) {
      s2 = new String[s1.length-1];
      for(int i=0;i<s1.length-1;i++) {
	s2[i]=s1[i+1];
      }
    }
  } else {
    s2 = s1;
  }
  return s2;
}
  
public void itemStateChanged(ItemEvent e) {
  if(e.getItem().toString().equals("0") &&
     e.getStateChange() == ItemEvent.SELECTED) {
    // 'ALL' clicked
    super.deselect(1);	// deselect 'None'
    for(int i=0;i<getItemCount();i++) {
      select(i);
    }
  } else if(e.getItem().toString().equals("1") &&
	    e.getStateChange() == ItemEvent.SELECTED) {
    // 'None' selected
    super.deselect(0);
    for(int i=0;i<getItemCount();i++) {
      deselect(i);
    }
  } else {
    // we have selected or deselected a particular network
    super.deselect(0);	// 'All'
    super.deselect(1);	// 'None'
  }
}

}
  
