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
  software, the FSL Software Policy Manager (softwaremgr@fsl.noaa.gov)
  should be notified.
</ul>
    
THIS SOFTWARE AND ITS DOCUMENTATION ARE IN THE PUBLIC DOMAIN AND ARE
FURNISHED "AS IS." THE AUTHORS, THE UNITED STATES GOVERNMENT, ITS
INSTRUMENTALITIES, OFFICERS, EMPLOYEES, AND AGENTS MAKE NO WARRANTY,
EXPRESS OR IMPLIED, AS TO THE USEFULNESS OF THE SOFTWARE AND
DOCUMENTATION FOR ANY PURPOSE. THEY ASSUME NO RESPONSIBILITY (1) FOR THE
USE OF THE SOFTWARE AND DOCUMENTATION; OR (2) TO PROVIDE TECHNICAL
SUPPORT TO USERS. 
*/
package sdg;
	
import lib.*;
import java.awt.*;
import java.awt.event.*;
import java.util.*;
import java.io.*;
import java.lang.System;
import java.lang.Runtime;
import java.net.*;

/**
* Lets the user choose a dewpoint, temperature and pressure
* for use in a parcel trajectory
* Revision history
* 13-Dec-99 started work
*/

public class ChooseDewpoint extends Frame
   implements MyButtonListener, ActionListener, ItemListener {

  static boolean is_faren = true;

  SoundingCanvas sc;
  int x,y;
  TextField t_tf,td_tf,p_tf;
  MyButton ok_btn;
  CheckboxGroup cent_faren;
  Checkbox faren_cb;
  Checkbox cent_cb;
  Font f;

public ChooseDewpoint(SoundingCanvas sc,int x, int y) {
  this.sc = sc;
  this.x = x;
  this.y = y;
  
  // handle window closing
  addWindowListener(new WindowAdapter() {
    public void windowClosing(WindowEvent e) {
      dispose();
    }});

  f = new Font("Dialog",Font.PLAIN,12);
  setTitle(" Choose Dewpoint, T, and P");

  String val;
  double temp;
  setLayout(new GridLayout(4,1));

  Panel top = new Panel();
  top.setLayout(new GridLayout(1,3));
  Label td_lab = new Label("Td",Label.CENTER);
  top.add(td_lab);
  Label t_lab = new Label("T",Label.CENTER);
  top.add(t_lab);
  Label p_lab = new Label("P (mb) ",Label.CENTER);
  top.add(p_lab);
  add(top);

  Panel mid = new Panel();
  mid.setLayout(new GridLayout(1,3));
  temp = get_temp(sc.td);
  val = MyUtil.goodRoundString(temp,-1e10,Sounding.MISSING-1,"",1);
  td_tf = new TextField(val,5);
  td_tf.addActionListener(this);
  Panel x1 = new Panel();
  x1.add(td_tf);
  mid.add(x1);
  temp = get_temp(sc.t);
  val = MyUtil.goodRoundString(temp,-1e10,Sounding.MISSING-1,"",1);
  t_tf = new TextField(val,5);
  t_tf.addActionListener(this);
  Panel x2 = new Panel();
  x2.add(t_tf);
  mid.add(x2);
  val = MyUtil.goodRoundString(sc.p,-1e10,Sounding.MISSING-1,"",1);
  p_tf = new TextField(val,6);
  p_tf.addActionListener(this);
  Panel x3 = new Panel();
  x3.add(p_tf);
  mid.add(x3);
  add(mid);

  Panel m2 = new Panel();
  cent_faren = new CheckboxGroup();
  faren_cb = new Checkbox("Fahrenheit",cent_faren,is_faren);
  faren_cb.addItemListener(this);
  m2.add(faren_cb);
  cent_cb = new Checkbox("Celsius",cent_faren,!is_faren);
  cent_cb.addItemListener(this);
  m2.add(cent_cb);
  add(m2);

  Panel bottom = new Panel();
  ok_btn = new MyButton(f," OK ",false);
  ok_btn.addListener(this);
  bottom.add(ok_btn);
  add(bottom);
  pack();
  Dimension size = getSize();
  //Dimension screen_size = Toolkit.getDefaultToolkit().getScreenSize();
  //Debug.println("screen size is "+screen_size);
  setLocation(x-size.width/2,y-size.height-20);
  td_tf.selectAll();
  show();
}

public double get_temp(double centigrade) {
  double result;
  if(centigrade == Sounding.MISSING) {
    result = Sounding.MISSING;
  } else if(!is_faren) {
    result =  centigrade;
  } else {
    result = 32. + centigrade*9/5;
  }
  return result;
}

public double get_cent(String temp) {
  double result;
  if(temp.equals("")) {
    result = Sounding.MISSING;
  } else if(!is_faren) {
    // temp is centigrade
    result = MyUtil.atof(temp);
  } else {
    // temp is fahrenheit
    result = (MyUtil.atof(temp) - 32)*(5./9.);
  }
  return result;
}
	  
  
public void actionPerformed(ActionEvent e) {
    if(e.getSource() == td_tf  ||
       e.getSource() == t_tf   ||
       e.getSource() == p_tf) {
      myAction(ok_btn);
    }
}

public void itemStateChanged(ItemEvent e) {
  if(e.getSource() == cent_cb) {
    show_faren(false);
  } else if(e.getSource() == faren_cb) {
    show_faren(true);
  }
}

public void myAction(MyButton b) {
  if(b == ok_btn) {
    sc.t = get_cent(t_tf.getText());
    sc.td = get_cent(td_tf.getText());
    sc.p = MyUtil.atof(p_tf.getText());
    setVisible(false);
    dispose();
    sc.plot_trajectory(sc.t,sc.td,sc.p);
    sc.repaint();
  }
}
public void show_faren(boolean to_faren) {
  double t= Sounding.MISSING;
  double td = Sounding.MISSING;
  //shows temperatures as fahrenheit or centigrade depending upon argument
  if(to_faren) {
    //translating to fahrenheit
    if(is_faren) {
      //nothing to do
      return;
    } else {
      //convert from centigrade to fahrenheit
      t = MyUtil.atof(t_tf.getText()) *(9./5.) +32.;
      td =MyUtil.atof(td_tf.getText())*(9./5.) +32.; 
      is_faren=true;
    }
  } else {
    //translate to centigrade
    if(!is_faren) {
      //nothing to do
      return;
    } else {
      //convert from fahrenheit to centigrade
      t = get_cent(t_tf.getText());
      td = get_cent(td_tf.getText());
      is_faren=false;
    }
  }
  String val;
  val = MyUtil.goodRoundString(t,-1e10,Sounding.MISSING-1,"",1);
  t_tf.setText(val);
  val = MyUtil.goodRoundString(td,-1e10,Sounding.MISSING-1,"",1);
  td_tf.setText(val);
}
  
} //end of class LoadSoundingsFrame
