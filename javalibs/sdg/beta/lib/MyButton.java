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
 * this implements 'sticky' buttons.  They optionally stay
 * pressed until the next mouse press.
 * they can also be pressed under program control.
 * Can't see a way to have this be an extension from Button,
 * and I can't see a way to register actionListeners.
 *
 *  6-March-2003 - added getMinimumSize() and getPreferredSize()
 */


public class MyButton extends Canvas {
  private Vector myButtonListeners=null;
  String title;
  Font f;
  FontMetrics fm;
  int height;
  int width;
  int x_text,y_text;
  boolean pressing,pressed;
  boolean toggle;
  boolean enabled=true;
  boolean control_down=false;
  boolean shift_down=false;
  Color top_color,bottom_color,text_color,background_color;
  
public MyButton(Font f, String _title, boolean _toggle) {
  title=_title;
  myButtonListeners = new Vector();
  this.f = f;
  setFont(f);
  fm = getFontMetrics(f);
  height = (int)(1.5*fm.getHeight());
  width = (int)(1.3*fm.stringWidth(title));
  y_text = height/2 + fm.getHeight()/3;
  setSize(width,height);
  pressed=false;
  pressing=false;
  toggle=_toggle;
  background_color = Color.lightGray;
  addMouseListener(new HandleMyButton());
}
  
public MyButton(Font f,String _title, boolean _toggle, int width) {
  this(f,_title,_toggle);
  this.width = width;
  setSize(width,height);
}
  
public void setBackground(Color c) {
  background_color = c;
}
  
public void setLabel(String _title) {
  title=_title;
  repaint();
}
  
public String getLabel() {
  return title;
}
  
public void reset() {
  pressed=false;
  pressing=false;
  repaint();
}

public void setEnabled(boolean enabled) {
  this.enabled = enabled;
  super.setEnabled(enabled);
  repaint();
}

public void indent() {
  //forces indentation of the button (no other actions)
  pressed=true;
  repaint();
}

public boolean controlDown() {
  return control_down;
}

public boolean shiftDown() {
  return shift_down;
}
  
public void unIndent() {
  //forces the button to pop out (no other actions)
  pressed = false;
  repaint();
}
  
public void paint(Graphics g) {
  g.setColor(background_color);
  g.fillRect(0,0,width,height);
  g.setColor(Color.black);
  //draw shadows
  if(pressing || pressed) {
    top_color = Color.black;
    bottom_color = Color.white;
  } else {
    top_color = Color.white;
    bottom_color = Color.black;
  }
  g.setColor(top_color);
  g.drawLine(2,1,width-2,1);  //top
  g.drawLine(1,height-2,1,1);   //left side
  g.setColor(bottom_color);
  g.drawLine(2,height-2,width-2,height-2);  //bottom
  g.drawLine(width-2,height-2,width-2,2); //right side
  x_text = width/2 - fm.stringWidth(title)/2;
  if(x_text < 2) {
    x_text = 2;
  }
  if(enabled) {
    text_color = Color.black;
  } else {
    text_color = Color.gray;
  }
  g.setColor(text_color);
  g.drawString(title,x_text,y_text);
}
  
public void addListener(MyButtonListener mbl) {
  if(myButtonListeners.contains(mbl)) {
    Debug.println("Error: trying to add the same MyButtonListener "+
		  "to MyButton more than once");
  } else {
    myButtonListeners.addElement(mbl);
  }
}

public void notifyListeners() {
  MyButtonListener mbl;
  for(int i=0;i<myButtonListeners.size(); i++) {
    mbl = (MyButtonListener) myButtonListeners.elementAt(i);
    mbl.myAction(this);
  }
}

  // override some Canvas methods to keep layout managers happy
public Dimension getMinimumSize() {
  return new Dimension(width,height);
}
public Dimension getPreferredSize() {
  return getMinimumSize();
}
  
private class HandleMyButton extends MouseAdapter {
public void mouseReleased(MouseEvent e) {
  if(enabled) {
    if(toggle) {
      pressed = ! pressed;
    }
    pressing=false;
    control_down = e.isControlDown();
    shift_down = e.isShiftDown();
    notifyListeners();
    repaint();
    
  }
}
public void mousePressed(MouseEvent e) {
  if(enabled) {
    pressing=true;
    repaint();
  }
}  
}
}
