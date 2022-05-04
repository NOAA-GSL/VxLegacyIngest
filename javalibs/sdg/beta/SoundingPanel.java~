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
import java.awt.image.ImageProducer;
import java.applet.Applet;
import java.io.*;
import java.lang.System;
import java.lang.Runtime;
import java.net.*;

/**
*  Class SoundingPanel plots soundings
*
*  @version a2.0 31-Aug-98<p>
*
*  @author Bill Moninger, NOAA, Forecast Systems Laboratory<p>
*/
public class SoundingPanel extends Panel
  implements MyButtonListener, FrameParent {

  SoundingDriver sd;
  SoundingCanvas displayArea;
  MyButton load_soundings_btn;
  MyButton text_sounding_btn;
  MyButton p_scale_btn;
  MyButton plot_type_btn;
  MyButton wind_scale_btn;
  Panel sdg_btn_panel;
  LoadSoundingsFrame load_soundings_frame;
  boolean showing_load_soundings_frame;
  public InfoFrame notASoundingFrame;
  InfoFrame tif;
  public boolean showing_notASoundingFrame=false;
  boolean background_loaded=false;
  boolean soundings_loaded=false;
  static boolean loading_soundings=false;
  String data_source;
  String data_sources;
  URL logURL=null;
  Sounding[] sounding = new Sounding[100];  //ought to be enough
  MyButton[] sounding_btn = new MyButton[100];
  int max_soundings=16;  //determined by number of buttons
  long freeMemory,totalMemory;
  static String log_file;
  String desired_airport="den";
  boolean initial_load=true;
  int startSecs = 938736000;// 1-Oct-99 0Z
  int endSecs = 938743200;  // 1-Oct-99 2Z
  double n_hrs;
  boolean latest = false;   // true if the 'latest' data is desired
  Font f;
  boolean action;
  boolean closed;
  static URL code_base;
  int plot_width;
  int plot_height;
  String str_10mb = " 10mb scale ";
  String str_150mb = "150mb scale";

  // Initialize.  Set our size and load the images
public SoundingPanel(SoundingDriver p) {
  this.sd=p;
  initial_load = sd.get_initial_load();
  log_file = sd.get_log_file();
  code_base = sd.get_code_base();
  Dimension d = sd.get_plot_size();
  plot_width = d.width;
  plot_height = d.height;
  Sounding.n_soundings=0;
  Sounding.n_soundings_to_plot=0;
}

public void init() {
  //this is called AFTER the panel is added to a frame,
  //so that a Peer has been created.
  
  //set up the screen
  //lay out the page
  setLayout(new GridBagLayout());
  
  //add the display area
  displayArea = new SoundingCanvas(this);
  MyUtil.addComponent(this,displayArea,0,0,1,1,0,0,0,0,0,0);
  //add("Center",displayArea);
  displayArea.init();
  displayArea.load_buffer();
  
  f = new Font("Helvetica", Font.PLAIN, 12);
  setFont(f);
  Panel control_panel = new Panel();
  control_panel.setLayout(new GridBagLayout());
  Panel options_btn_panel = new Panel();
  
  //FontMetrics val_fm=offScrGC.getFontMetrics(val_font);
  //int val_height = val_fm.getHeight();
  load_soundings_btn = new MyButton(f,sd.get_load_btn_title(),
				    true);
  load_soundings_btn.addListener(this);
  options_btn_panel.add(load_soundings_btn);
  if(sd.get_load_btn_title().equals("")) {
    load_soundings_btn.setEnabled(false);
  }
  text_sounding_btn = new MyButton(f,"Get text",false);
  text_sounding_btn.addListener(this);
  options_btn_panel.add(text_sounding_btn);
  p_scale_btn = new MyButton(f,str_10mb,false);
  p_scale_btn.addListener(this);
  options_btn_panel.add(p_scale_btn);
  plot_type_btn = new MyButton(f,"SkewT/Tephi.",false);
  plot_type_btn.addListener(this);
  options_btn_panel.add(plot_type_btn);
  wind_scale_btn = new MyButton(f,"Wind scale: 40/100",false);
  wind_scale_btn.addListener(this);
  options_btn_panel.add(wind_scale_btn);
  MyUtil.addComponent(control_panel,options_btn_panel,0,0,1,1,0,0,0,0,0,0);

  sdg_btn_panel = new Panel();
  sdg_btn_panel.setLayout(new GridLayout(4,4));
  sdg_btn_panel.setFont(f);
  int btn_width = 170; //getMinimumSize().width/4;
  for(int i = 0;i<max_soundings;i++) {
    sounding_btn[i]=new MyButton(f,"  ",false,btn_width);
    sounding_btn[i].addListener(this);
    sdg_btn_panel.add(sounding_btn[i]);
  }
  MyUtil.addComponent(control_panel,sdg_btn_panel,0,1,1,1,0,0,0,0,0,0);
  MyUtil.addComponent(this,control_panel,0,1,1,1,0,0,0,0,0,0);
  //add("South",control_panel);

  // get the data sources for the buttons on the LoadSoundingsFrame
  data_sources = sd.get_data_sources();
  Debug.println("data sources are "+data_sources);
  
  //load the initial data
  if(initial_load) {
    desired_airport = sd.get_desired_airport();
    startSecs = sd.get_startSecs();
    endSecs = sd.get_endSecs();
    n_hrs = (endSecs - startSecs)/3600.;
    latest = sd.get_latest();
    data_source = sd.get_data_source();
    start_load();
    initial_load=false;
  }
}
  
public void stop() {
  Debug.println("SoundingPanel stop called");
  SoundingLoader.stop_loader();
  
  if(load_soundings_frame != null) {
    load_soundings_frame.setVisible(false);
    load_soundings_frame.dispose();
    load_soundings_frame = null;
    showing_load_soundings_frame=false;
    load_soundings_btn.unIndent();
  }
  if(notASoundingFrame != null) {
    notASoundingFrame.dispose();
    notASoundingFrame=null;
    showing_notASoundingFrame=false;
  }
  //dispose the text sounding frame if needed
  if(tif != null) {
    tif.dispose();
    tif=null;
  }
  sd.set_showing_soundingsFrame(false);
  sd.set_soundingsFrame_btn("reset");
}

public void destroy() {
    Debug.println("Destroy called");
    SoundingLoader.stop_loader();

    if(load_soundings_frame != null) {
      load_soundings_frame.setVisible(false);
      load_soundings_frame.dispose();
      load_soundings_frame=null;
    }
  }

public void start_load() {
    new SoundingLoader(this);
  }


public void myAction(MyButton b){
  if(b == load_soundings_btn ) {
    if(load_soundings_frame != null) {
      load_soundings_frame.dispose();
      load_soundings_frame=null;
    }
    load_soundings_frame = new LoadSoundingsFrame(this);
    load_soundings_frame.pack();
    if(showing_load_soundings_frame) {
      load_soundings_frame.setVisible(false);
      load_soundings_frame.dispose();
      showing_load_soundings_frame=false;
    } else {
      load_soundings_frame.setVisible(false);
      load_soundings_frame.show();
      showing_load_soundings_frame=true;
    }
  } else if (b == text_sounding_btn) {
    if(Sounding.n_soundings_to_plot == 1) {
      Sounding s = sounding[Sounding.soundings_to_plot[0]];
      String text = s.getFullText();
      //Debug.println(text);
      if(tif != null) {
	tif.dispose();
	tif=null;
      }
      tif = new InfoFrame(text, 780,580,
			  new Font("Courier",Font.PLAIN,12));
      tif.show();
      String log_argument="sdg_text="+s.getShortTitle();
      Logger logger =
	new Logger(sd.get_code_base(),sd.get_log_file(),
		   log_argument);
    }
  } else if (b == p_scale_btn) {
    if(p_scale_btn.getLabel().equals(str_10mb)) {
      p_scale_btn.setLabel(str_150mb);
      displayArea.set_10mb();
    } else {
      p_scale_btn.setLabel(str_10mb);
      displayArea.reset();
    }
  } else if(b == wind_scale_btn) {
    displayArea.toggle_wind_scale();
  } else if(b == plot_type_btn) {
    displayArea.toggle_plot_type();
    String log_argument="tephi_toggle.";
    Logger logger =
      new Logger(sd.get_code_base(),sd.get_log_file(),
		 log_argument);
  } else {
    for(int i = 0;i<Sounding.n_soundings;i++) {
      if(b == sounding_btn[i]) {
	if(b.controlDown() && sounding[i] != null) {
	  //delete sounding
	  reset_buttons();
	  //Debug.println("Deleting sounding "+sounding[i]);
	  Sounding.n_soundings_to_plot=0;
	  for(int j = i;j<Sounding.n_soundings;j++) {
	    sounding[j] = sounding[j+1];
	    sounding[j+1]=null;
	    sounding_btn[j].setLabel(sounding_btn[j+1].getLabel());
	    sounding_btn[j+1].setLabel("");
	  }
	  Sounding.n_soundings--;
	  //Debug.println("now there are this many "+Sounding.n_soundings);
	  displayArea.plot_sounding();
	  displayArea.repaint();
	} else if(b.shiftDown() && sounding[i] != null) {
	  //add a sounding to the plot
	  int new_plot_index = Sounding.n_soundings_to_plot;
	  Sounding.soundings_to_plot[new_plot_index]=i;
	  Sounding.n_soundings_to_plot++;
	  //Debug.println("Now there are these soundings to plot "+
	  //Sounding.n_soundings_to_plot);
	  sounding_btn[i].indent();
	  sounding_btn[i].setBackground(
			  SkewTPlot.sounding_color[new_plot_index]);
	  displayArea.plot_sounding();
	  displayArea.repaint();
	} else {
	  //show sounding
	  reset_buttons();
	  sounding_btn[i].indent();
	  Sounding.n_soundings_to_plot=1;
	  Sounding.soundings_to_plot[0]=i;
	  displayArea.plot_sounding();
	  displayArea.repaint();
	}
      }
    }
  }
}

public void reset_buttons() {
  for(int i =0;i<Sounding.n_soundings;i++) {
    sounding_btn[i].reset();
    sounding_btn[i].setBackground(Color.lightGray);
  }
}

public void add_show_sounding(Sounding s) {
  //push down other soundings
  Debug.println("pushing down soundings");
  if(Sounding.n_soundings == max_soundings) {
    Debug.println("nulling out sounding "+max_soundings);
    sounding[max_soundings-1]=null;
    Sounding.n_soundings--;
  }
  for(int j = Sounding.n_soundings-1;j>=0;j--) {
    sounding[j+1] = sounding[j];
    sounding_btn[j+1].setLabel(""+sounding[j+1]);
  }
  sounding[0] = s;
  Sounding.n_soundings_to_plot=1;
  Sounding.soundings_to_plot[0]=0;
  Sounding.n_soundings++;
  sounding_btn[0].setLabel(""+s);
  reset_buttons();
  sounding_btn[0].indent();
  displayArea.plot_sounding();
  displayArea.repaint();
  //set up default airport for use in the loadSoundingsFrame
  desired_airport = s.station_name;
  // date for log file
  UTCDate d = s.ground_date;
  int year = d.getYear();
  String month_name = d.getMonthName();
  int mday = d.getDay();
  int hour = d.getHour();
  String log_argument = "sounding="+s.getShortTitle()+
    "&year="+year+"&month_name="+month_name+
    "&mday="+mday+"&hour="+hour;
  Logger logger = new Logger(sd.get_code_base(),log_file,log_argument);
  //for the first sounding only, update the default times
  //used by LoadSoundingsFrame
  if(Sounding.n_soundings==1) {
    startSecs = d.get1970Secs();
    endSecs = startSecs+(int)(3600*n_hrs);
  }
}

public void frameAction(Frame f, boolean action, boolean closed) {
  if(f == load_soundings_frame) {
    if(action) {
      latest=false;
      start_load();
    }
    if(closed) {
      load_soundings_frame.setVisible(false);
      showing_load_soundings_frame = false;
      load_soundings_btn.unIndent();
    }
  }
}

}  //end of class SoundingPackage



