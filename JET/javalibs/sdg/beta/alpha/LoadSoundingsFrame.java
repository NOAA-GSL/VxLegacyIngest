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
* Loads new soundings
* Revision history
* 30-Sep-99 - changed to ask for a start and end date
*  3-Jan-02 - upgraded to Java 1.1 event model
*/

public class LoadSoundingsFrame extends Frame
    implements MyButtonListener {


  SoundingPanel creator;
  TextField apt;
  TextField start_year_tf;
  Choice start_month_name_ch;
  Choice start_mday_ch;
  Choice start_hour_ch;
  Choice start_min_ch;
  TextField n_hrs_tf;
  int start_year;
  String start_month_name;
  int start_mday;
  int start_hour;
  UTCDate start_date;
  double n_hrs;
  Font f;
  boolean closed=false;
  boolean action=false;
  int max_sources = 10;
  String[] data_source_title = new String[max_sources];
  String[] data_source_id = new String[max_sources];
  MyButton[] source_btn = new MyButton[max_sources];
  int n_sources = 0;

public LoadSoundingsFrame(SoundingPanel _creator) {
  creator=_creator;
  f = creator.f;

  // handle window closing
  addWindowListener(new WindowAdapter() {
      public void windowClosing(WindowEvent e) {
	closed=true;
	action=false;
	creator.frameAction(LoadSoundingsFrame.this,action,closed);
      }});
    
    start_date = new UTCDate(creator.startSecs);
    n_hrs = (creator.endSecs - creator.startSecs)/3600.;
    Debug.println("n_hrs in LoadSoundingsFrame: "+n_hrs);
    start_year = start_date.getYear();
    start_month_name = start_date.getMonthName();
    start_mday = start_date.getDay();
    start_hour = start_date.getHour();

    setTitle(" Choose Sounding");
    //Debug.println("Creating LoadFrame");
    int n_frame_rows=0;

    //set things up
    // first, get possible data sources so we know how many rows to allow
    StringTokenizer items =
      new StringTokenizer(creator.data_sources,",");
    int n_rows = 4 + (items.countTokens()-1)/6 + 1;

    setLayout(new GridBagLayout());

    Color color1 = new Color(204,255,255);
    Color color2 = new Color(255,255,204);
    
    Panel north = new Panel();
    north.setBackground(color1);
    Label lab = new Label("Choose a site or lat,lon: ");
    north.add(lab);
    apt = new TextField(creator.desired_airport,7);
    north.add(apt);
    //add(north);
    MyUtil.addComponent(this,north,0,n_frame_rows++,1,1,0,0,0,0,0,0);

    Panel pnorm = new Panel();
    pnorm.setBackground(color2);
    pnorm.setLayout(new GridBagLayout());

    Label lab2 = new Label("Start date: ");
    MyUtil.addComponent(pnorm,lab2,0,0,1,2,0,0);

    start_year_tf = new TextField(""+start_year,5);
    MyUtil.addComponent(pnorm,start_year_tf,1,0,1,1,0,0);

    start_month_name_ch = new MonthChoice();
    start_month_name_ch.select(start_month_name);
    MyUtil.addComponent(pnorm,start_month_name_ch,2,0,1,1,0,0);

    start_mday_ch = new MonthDaysChoice();
    start_mday_ch.select(""+start_mday);
    MyUtil.addComponent(pnorm,start_mday_ch,3,0,1,1,0,0);

    Label lab3n = new Label("hour, min:");
    MyUtil.addComponent(pnorm,lab3n,1,1,1,1,0,0);
    start_hour_ch = new HoursChoice();
    start_hour_ch.select(""+start_hour);
    MyUtil.addComponent(pnorm,start_hour_ch,2,1,1,1,0,0);

    start_min_ch = new Choice();
    start_min_ch.addItem("0");
    start_min_ch.addItem("5");
    start_min_ch.addItem("10");
    start_min_ch.addItem("15");
    start_min_ch.addItem("20");
    start_min_ch.addItem("25");
    start_min_ch.addItem("30");
    start_min_ch.addItem("35");
    start_min_ch.addItem("40");
    start_min_ch.addItem("45");
    start_min_ch.addItem("50");
    start_min_ch.addItem("55");
    MyUtil.addComponent(pnorm,start_min_ch,3,1,1,1,0,0);

    //add(pnorm);
    MyUtil.addComponent(this,pnorm,0,n_frame_rows++,1,1,0,0,0,0,0,0);

    Panel center2 = new Panel();
    center2.setBackground(color1);
    Label lab22 = new Label(" Number of hours to load: ");
    center2.add(lab22);
    n_hrs_tf = new TextField(""+n_hrs,5);
    center2.add(n_hrs_tf);
    //add(center2);
    MyUtil.addComponent(this,center2,0,n_frame_rows++,1,1,0,0,0,0,0,0);

    Panel south = new Panel();
    south.setBackground(color2);
    Label load_lab = new Label("Source for sounding: ");
    south.add(load_lab);
    //add(south);
    MyUtil.addComponent(this,south,0,n_frame_rows++,1,1,0,0,0,0,0,0);
   
    n_sources=0;
    int n_pan=-1;
    Panel[] pan = new Panel[max_sources/4 + 1];
    while(items.hasMoreElements() && n_sources < max_sources) {
      if(n_sources % 4 == 0) {
	// set up a new panel
	// first add any previous panel
	if(n_pan >= 0) {
	  //add(pan[n_pan]);
	  pan[n_pan].setBackground(color2);
	  MyUtil.addComponent(this,pan[n_pan],0,n_frame_rows++,1,1,0,0
			      ,0,0,0,0);
	}
	n_pan++;
	// new panel every 4 sources
	pan[n_pan] = new Panel();
      }
      data_source_title[n_sources] = items.nextToken();
      data_source_id[n_sources] = items.nextToken();
      source_btn[n_sources] =
	new MyButton(f,data_source_title[n_sources],false);
      source_btn[n_sources].addListener(this);
      pan[n_pan].add(source_btn[n_sources]);
      n_sources++;
    }
    //add(pan[n_pan]);
    pan[n_pan].setBackground(color2);
    MyUtil.addComponent(this,pan[n_pan],0,n_frame_rows++,1,1,0,0
			,0,0,0,0);
    
    n_pan++;
}
  
public void myAction(MyButton b) {
  for(int i=0;i<n_sources;i++) {
    if(b == source_btn[i]) {
      creator.data_source = data_source_id[i];
    }
  }
  creator.desired_airport = apt.getText();
  start_date = new UTCDate(
			   MyUtil.atoi(start_year_tf.getText()),
			   start_month_name_ch.getSelectedItem(),
			   MyUtil.atoi(start_mday_ch.getSelectedItem()),
			   MyUtil.atoi(start_hour_ch.getSelectedItem()),
			   MyUtil.atoi(start_min_ch.getSelectedItem()),
			   0);
  creator.startSecs = start_date.get1970Secs();
  // put on an hour boundry
  creator.startSecs -= creator.startSecs%3600;
  creator.endSecs = creator.startSecs +
    (int)(3600*MyUtil.atof(n_hrs_tf.getText()));
  
  creator.frameAction(this,true,false);
}

} //end of class LoadSoundingsFrame
