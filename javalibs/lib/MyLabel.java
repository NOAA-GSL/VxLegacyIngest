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
/**
 * this hand-draws fonts to overcome a font problem on linux
 * when linux java fonts are fixed, this can go away.
 */
public class MyLabel extends Canvas {
  String title;
  Font f;
  FontMetrics fm;
  int height;
  int width;
  int x_text = 0;
  int y_text = 0;
  Color default_foreground_color= Color.black;
  Color default_background_color = Color.white;
  Color foreground_color = default_foreground_color;
  Color background_color = default_background_color;

public MyLabel(Font f, String title) {
  this.title = title;
  this.f = f;
  setFont(f);
  fm = getFontMetrics(f);
  set_size();
}

private void set_size() {
  height = (int)(1.5*fm.getHeight());
  width = (int)(1.1*fm.stringWidth(title));
  y_text = height/2 + fm.getHeight()/3;
  setSize(width,height);
}
  
public void setText(String title) {
  this.title = title;
  set_size();
  repaint();
}

public void setForeground(Color c) {
  foreground_color = c;
}
  
public void setBackground(Color c) {
  background_color = c;
}

public void paint(Graphics g) {
  g.setColor(background_color);
  g.fillRect(0,0,width,height);
  g.setColor(foreground_color);
  g.drawString(title,x_text,y_text);
}

// override some Canvas methods to keep layout managers happy
public Dimension getMinimumSize() {
  return new Dimension(width,height);
}
public Dimension getPreferredSize() {
  return getMinimumSize();
}
   
} 
