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
* paints the screen from an off screen image without clearing first.
*/
class SoundingCanvas extends Canvas
  implements MouseListener, MouseMotionListener {

  static double K0 = 273.15;	// (minus) zero K in celsius
  ThermoPack thp = new ThermoPack(0,0,0); // stores thermodynamic values
  String skewt = "SkewT-log P";
  String tephi = "Tephigram";
  String plot_type = skewt;
  int wind_scale = 100;
  int ylmy,xmdy;		// used in get_thermo
  double dy;			// used in get_xy
  Font f;
  SoundingPanel sp;
  SkewTPlot stp;
  SoundingLevel last_lev;
  int rad_ho,x_ho,y_ho;  //center of hodograph
  int ho_size;			// side of (square_ hodograph)
  double scale_ho;    // dx = scale_ho * (u in kts)
  boolean want_hodo=true;	// true if the user wants a hodograph
				// even tho we're plotting a flight
  // limits of "button" to switch between hodo and flt track
  int ho_switch_min_x,ho_switch_max_x;
  int ho_switch_min_y,ho_switch_max_y;
  Color color_ho;
  Point mouse_pt;
  Point start_mouse_pt;
  int zoom_x1,zoom_y1,zoom_x_range,zoom_y_range;
  double aspect_ratio;
  boolean dragging=false;
  boolean first_buffer_load=true;  //dont log the first load of the buffer
  // Our off-screen components for double buffering.
  Image background_image,plot_image;
  Graphics bg,pg;  //graphics for background and plot
  // values below are various positions in fractions of the plot size
  int x_lower,x_upper,x_barb,x_50,x_100,y_lower,y_upper;
  int plot_width;
  int plot_height;
  //fixed values for the max zoom-out values
  double mb10_p_lr=1050;
  double mb10_p_ur=10;
  double mb10_t_ll=-80;
  double mb10_t_lr=110;
  double mb10_theta_ll = -82.6765;
  double mb10_theta_lr = 104.69066;
  double t,td,p;       // used to pass values of temp, dewpt and pressure
  double p_lr,p_ur,t_ll,t_lr;
  double theta_ll,theta_lr; // used for tephigram
  double p_to_y;     //factor to help convert p to y
  double mlpl;        //ditto
  double t_to_x_at_p_lr;  //factor to help convert t to x
  double speed_to_x;  //factor to help convert windSpeed to an x increment
  double tephi_scale;	  // factor for tephi, but cud be used for Skt too
  double theta;
  int[] isobar = { 1050,1000,900,800,700, 600,500, 400,300, 200,  100,
		   80,60,40,20,10};
  int[] ft_alts =    {1000,5000,10000,15000,20000,25000,30000,35000,
		      40000,60000,80000,100000};
  double[] mx_rat = { .1,.2,.4,.6,1.,1.5,2.,4,5,6,7,8,10,12,14,18,22,
		      26,32,38,46 };

public SoundingCanvas(SoundingPanel sp) {
  this.sp=sp;
  addMouseListener(this);
  addMouseMotionListener(this);
  stp = new SkewTPlot(this);
  last_lev = null;
  mouse_pt = new Point(-1,-1);
  plot_width = sp.plot_width;
  plot_height = sp.plot_height;
  p_lr=SoundingDriver.default_p_lr;
  p_ur=SoundingDriver.default_p_ur;
  t_lr=SoundingDriver.default_t_lr;
  t_ll=SoundingDriver.default_t_ll;
  theta_lr=SoundingDriver.default_theta_lr;
  theta_ll=SoundingDriver.default_theta_ll;
  setSize(sp.plot_width,sp.plot_height);
  x_lower = (int)( 0.1  * plot_width);
  x_upper = (int)( 0.8  * plot_width);
  x_barb =  (int)( 0.88 * plot_width);
  x_50 =    (int)( 0.92 * plot_width);
  x_100 =   (int)( 0.96 * plot_width);
  y_lower = (int)( 0.9  * plot_height);
  y_upper = (int)( 0.05 * plot_height);
  aspect_ratio = (double)(y_lower - y_upper)/(x_upper - x_lower);
  
  //calculated variables
  speed_to_x = (x_100 - x_barb)/(wind_scale+0.0);
  set_mapping();
}

public void init() {
  f = new Font("Helvetica", Font.PLAIN, 10);
  background_image = createImage(plot_width,plot_height);
  bg = background_image.getGraphics();
  plot_image = createImage(plot_width,plot_height);
  pg = plot_image.getGraphics();
  first_buffer_load=true;
}

public void set_mapping() {
  /*
   * mapping point definitions
   * p_ur =  pressure at upper right corner
   * p_lr = pressure at lower right corner
   * t_lr = temperature at lower right corner (Celsius)
   * t_ll = temperature at lower left corner
   * theta_ll and theta_lr used for tephigram
   * theta_ll = potential temperature at lower left corner
   * theta lr = potential temperature at lower right corner
   */
  
  mlpl = Math.log(p_lr);
  p_to_y = (y_lower - y_upper)/(Math.log(p_ur) - mlpl);
  Debug.println("p_to_y is "+p_to_y);
  t_to_x_at_p_lr = (x_upper - x_lower)/(t_lr - t_ll);
  Debug.println("t_to_x_at_p_lr is "+t_to_x_at_p_lr);
  Debug.println("p_lr: "+p_lr+", p_ur: "+p_ur);
  tephi_scale = (x_upper - x_lower)/(t_lr - t_ll) * .7071;
}

public void reset() {
  p_lr=SoundingDriver.default_p_lr;
  p_ur=SoundingDriver.default_p_ur;
  t_ll=SoundingDriver.default_t_ll;
  t_lr=SoundingDriver.default_t_lr;
  theta_lr=SoundingDriver.default_theta_lr;
  theta_ll=SoundingDriver.default_theta_ll;
  set_mapping();
  load_buffer();
  repaint();
}

public void set_10mb() {
  //sets a 10mb map
  p_lr=mb10_p_lr;
  p_ur=mb10_p_ur;
  t_ll=mb10_t_ll;
  t_lr=mb10_t_lr;
  theta_ll=mb10_theta_ll;
  theta_lr=mb10_theta_lr;
  set_mapping();
  //sp.mb10_btn.indent();
  load_buffer();
  get_thermo(x_upper,y_lower,thp);
  /* remove later
  Debug.println("lower right t: "+thp.t+",  pr: "+thp.pr+", th: "+thp.theta);
  get_thermo(x_lower,y_lower,thp);
  Debug.println("lower left t: "+thp.t+",  pr: "+thp.pr+", th: "+thp.theta);
  */
  repaint();
}

public void toggle_wind_scale() {
  if(wind_scale == 100) {
    wind_scale = 40;
  } else {
    wind_scale = 100;
  }
  speed_to_x = (x_100 - x_barb)/(double)wind_scale;
  load_buffer();
  repaint();
}

public void toggle_plot_type() {
  if(plot_type.equals(skewt)) {
    plot_type = tephi;
  } else {
    plot_type = skewt;
  }
  load_buffer();
  repaint();
}
      
public boolean is_on_plot(Point p) {
  if(p.x < x_lower || p.x > x_upper ||
     p.y < y_upper || p.y > y_lower) {
     // on hodograph
     //(p.x < x_lower+ho_size && p.y < y_upper+ho_size)) {
    return false;
  }
  return true;
}

public void get_xy(double press, double t, Point p) {
  if(plot_type.equals(skewt)) {
    dy = p_to_y*(Math.log(press) - mlpl);
    p.y = y_lower - (int)dy;
    p.x = 0;
    if(t < 99998.) {
      //Debug.println("dy is "+dy);
      double x_at_p_lr = t_to_x_at_p_lr*(t - t_ll) + x_lower;
      //Debug.println("x_at_p_lr is "+x_at_p_lr+" p:  "+press+", t: "+t);
      p.x = (int)(x_at_p_lr + dy);
      //Debug.println("point returned: "+p);
    }
  } else if(plot_type.equals(tephi)) {
    theta = (t+K0)*Math.pow(1000/press,.286) - K0 - theta_ll;
    theta *= tephi_scale;
    t = t - t_ll;
    t *= tephi_scale;
    p.x = (int)((theta + t)*0.7071) + x_lower;
    p.y = y_lower - (int)((theta - t)*0.707);
  }
}

public void get_thermo(int x, int y, ThermoPack thp) {
  if(plot_type.equals(skewt)) {
    ylmy = y_lower - y;
    xmdy = x - ylmy;  //shift x back to its value at y_lower
    thp.t = (float)(t_ll + (xmdy - x_lower)/t_to_x_at_p_lr);
    thp.pr = (float)Math.exp(ylmy/p_to_y + mlpl);
    thp.theta = (float)((thp.t+K0)*Math.pow(1000/thp.pr,.286) - K0);
  } else if(plot_type.equals(tephi)) {
    x = x - x_lower;
    y = y_lower - y;
    thp.t = (float)((x-y)/(2.*0.7071*tephi_scale) + t_ll);
    thp.theta = (float)((x+y)/(2*.7071*tephi_scale) + theta_ll);
    thp.pr = (float)
      (1000/Math.pow((thp.theta+K0)/(thp.t+K0),3.4965));
    //Debug.println(""+thp);
  }
}

/** gets y for a given pressure and x
 */
public int get_y(double pr,int x) {
  int ypix=0;
  if(plot_type.equals(skewt)) {
    dy = p_to_y*(Math.log(pr) - mlpl);
    ypix = y_lower - (int)dy;
  } else if(plot_type.equals(tephi)) {
    double a = Math.pow(1000/pr,.286);
    double K1 = theta_ll + t_ll + 2* K0;
    double s = tephi_scale*0.7071;
    double K2 = t_ll - theta_ll;
    x -= x_lower;			// x wrt lower left corner
    // this y is with respect to the lower left corner
    double y = s*((x/s + K1)*(a-1)/(a+1) + K2);
    ypix = (int)(y_lower - y);
  }
  return ypix;
}
  
public void load_buffer() {
  Point pt = new Point(-1,-1);
  Point pt_last = new Point(-1,-1);
  boolean titled=false;
  String val;
  
  //clear the screen
  bg.setColor(Color.white);
  bg.fillRect(0,0,plot_width,plot_height);
  
  //draw saturated adiabats
  Color brown = new Color(255,110,0);
  bg.setColor(brown);
  int t_inc=10;
  int t_stop=50;
  double pr_inc = 0.95;
  if(t_lr - t_ll > 120) {
    t_inc = 20;
    t_stop = 40;
    pr_inc = 0.9;
  }
  for(int t = (int)t_ll;t<t_stop;t+=t_inc) {
    titled=false;
    double pr_this=p_lr;
    double t_this;
    double theta_e = Stability.parcelThetaE(t+K0,t+K0,1000);
    pt_last.x = -1;
    while(true) {
      t_this = Stability.tempAlongSatAdiabat(theta_e,pr_this) - K0;
      get_xy(pr_this,t_this,pt);
      if(pt_last.x != -1) {
	bg.drawLine(pt_last.x,pt_last.y,pt.x,pt.y);
      }
      if(pt.y < .75*y_lower && ! titled) {
	MyUtil.drawCleanString(""+t,bg, f,pt.x, pt.y,
			       0.3,brown,Color.white,1);
	titled=true;
      }
      pr_this = pr_this*pr_inc;
      if(pr_this < 200) {
	break;
      }
      // keep pt and pt_last as separate memory locations
      pt_last.x = pt.x;
      pt_last.y = pt.y;
    }
  }
  
  //draw mixing ratios, if we are below 200 mb
  bg.setColor(Color.gray);
  if(p_lr > 200) {
    double p_top = Math.max(p_ur,200);
    int digits=1;
    for(int i=0;i<mx_rat.length;i++) {
      double t1 = tmr(mx_rat[i],p_lr);
      get_xy(p_lr,t1,pt_last);
      double t2 = tmr(mx_rat[i],p_top);
      get_xy(p_top,t2,pt);
      bg.drawLine(pt_last.x,pt_last.y,pt.x,pt.y);
      if(mx_rat[i] >= 4) digits=0;
      val = MyUtil.goodRoundString(mx_rat[i],0,1.e10,"",digits);
      MyUtil.drawCleanString(val,bg, f,pt_last.x,pt_last.y,
			     0.3,Color.gray,Color.white,0);
      MyUtil.drawCleanString(val,bg, f,pt.x-14,pt.y,
			     0.5,Color.gray,Color.white,2);
    }
  }
  
  //draw altitude lines
  bg.setColor(Color.blue);
  for(int i = 0;i<ft_alts.length;i++) {
    // skip 10,000 and 30,000 ft because they overlap
    // isobars and make the plot look back
    if(ft_alts[i] != 10000 && ft_alts[i] != 30000) {
      double press = Sounding.getStdPressure(ft_alts[i]);
      pt_last.x = -1;
      for(int t = -200;t<200;t+=10) {
	get_xy(press,t,pt);
	if(pt_last.x != -1) {
	  bg.drawLine(pt_last.x,pt_last.y,pt.x,pt.y);
	}
	// keep pt and pt_last as separate memory locations
	pt_last.x = pt.x;
	pt_last.y = pt.y;
      }
    }
  }

  //draw isobars
  bg.setColor(Color.black);  
  for(int i=0;i<isobar.length;i++) {
    pt_last.x = -1;
    for(int t = -200;t<200;t+=1) {
      get_xy(isobar[i],t,pt);
      if(pt_last.x != -1) {
	bg.drawLine(pt_last.x,pt_last.y,pt.x,pt.y);
      }
      // keep pt and pt_last as separate memory locations
      pt_last.x = pt.x;
      pt_last.y = pt.y;
    }
  }

  //draw dry adiabats
  bg.setColor(Color.blue);
  int theta_inc=10;
  int theta_stop=130;
  pr_inc = 0.97;
  if(t_lr - t_ll > 120) {
    theta_inc = 20;
    theta_stop = 290;
    pr_inc = 0.9;
  }
  for(int theta = (int)t_ll;theta<theta_stop;theta+=theta_inc) {
    titled=false;
    double pr_this = p_lr;
    double t_this;
    pt_last.x = -1;
    while(true) {
      t_this = (theta+K0)*Math.pow(1000/pr_this,-.286) - K0;
      get_xy(pr_this,t_this,pt);
      if(pt_last.x != -1) {
	bg.drawLine(pt_last.x,pt_last.y,pt.x,pt.y);
      }
      if(pt.y < .65*y_lower && ! titled) {
	MyUtil.drawCleanString(""+theta,bg, f,pt.x, pt.y,
			       0.3,Color.blue,Color.white,1);
	titled=true;
      }
      pr_this = pr_this*pr_inc;
      if(pt.y < y_upper) {
	break;
      }
      // keep pt and pt_last as separate memory locations
      pt_last.x = pt.x;
      pt_last.y = pt.y;
    }
  }
  
  //draw isotherms
  bg.setColor(Color.red);
  for(int t = -140 ; t<= t_lr; t += 10) {
    titled = false;
    pt_last.x = -1;
    double pr_this = 1050;
    pr_inc = 0.95;
    while(true) {
      get_xy(pr_this,t,pt);
      if(pt_last.x != -1) {
	bg.drawLine(pt_last.x,pt_last.y,pt.x,pt.y);
      }
      if(!titled && pt.y < .95*y_lower) {
	val = ""+t;
	MyUtil.drawCleanString(val,bg, f,pt.x, pt.y,
			     1,Color.red,Color.white,1);
	titled=true;
      }
      pr_this *= pr_inc;
      if(pt.y < y_upper) {
	break;
      }
      // keep pt and pt_last as separate memory locations
      pt_last.x = pt.x;
      pt_last.y = pt.y;
    }
  }
  
  //clean up the border
  bg.setColor(Color.white);
  // left side
  bg.fillRect(0,0,x_lower,plot_height);
  // right side
  bg.fillRect(x_upper,0,plot_width-x_upper,y_lower);
  // bottom
  bg.fillRect(0,y_lower,plot_width,plot_height-y_lower);
  // plot border
  bg.setColor(Color.black);
  bg.drawRect(x_lower,y_upper, x_upper - x_lower, y_lower - y_upper);

  //titles on the outside of the plot
  Font midf = new Font("Dialog",Font.PLAIN,14);
  MyUtil.drawCleanString(plot_type,bg,midf,
			 x_lower+(x_upper-x_lower)/2,y_lower+2,
			 0.5,Color.red,Color.white,1);
  
  Font bigf = new Font("Helvetica", Font.BOLD, 16);
  MyUtil.drawCleanString("NOAA / ESRL / GSD",bg, bigf,
			 plot_width/2, plot_height,
			 0.4,Color.blue,Color.white,0);
  
  
  MyUtil.drawCleanString("Press Alt.",bg, f,
			 x_upper+(x_barb-x_upper)/2, y_lower+12,
			 0.5,Color.blue,Color.white,1);
  MyUtil.drawCleanString("(Kft.)",bg, f,x_upper+(x_barb-x_upper)/2, y_lower+24,
			 0.5,Color.blue,Color.white,1);

  // pressure legend, on right
  for(int i=0;i<isobar.length;i++) {
    int y = get_y(isobar[i],x_lower);
    val = ""+isobar[i];
    MyUtil.drawCleanString(val,bg, f,x_lower-5,y,
			   1,Color.black,Color.white,0.5);
  }

  // draw altitude lines and legend
  bg.setColor(Color.blue);
  int extra = (x_100-x_50)/2;
  for(int i = 0;i<ft_alts.length;i++) {
    double pr = Sounding.getStdPressure(ft_alts[i]);
    int y = get_y(pr,x_upper);
    //bg.drawLine(x_barb-extra,y,x_100+extra,y);
    bg.drawLine(x_upper,y,x_100+extra,y);
    val = ""+(int)(ft_alts[i]/1000.);
    MyUtil.drawCleanString(val,bg, f,x_upper+(x_barb-x_upper)/2,y,
			   0.5,Color.blue,Color.white,0.5);
  }
     
  
  //draw wind lines
  bg.setColor(Color.black);
  bg.drawLine(x_barb,y_lower,x_barb,y_upper);
  bg.drawLine(x_50,y_lower,x_50,y_upper);
  bg.drawLine(x_100,y_lower,x_100,y_upper);
  MyUtil.drawCleanString("0",bg, f,x_barb, y_lower+2,
			 0.5,Color.blue,Color.white,1);
  MyUtil.drawCleanString(""+wind_scale/2,bg, f,x_50, y_lower+2,
			 0.5,Color.blue,Color.white,1);
  MyUtil.drawCleanString(""+wind_scale,bg, f,x_100, y_lower+2,
			 0.5,Color.blue,Color.white,1);
  MyUtil.drawCleanString("kts",bg, f,x_50, y_lower+14,
			 0.5,Color.blue,Color.white,1);
  
  //draw x and y labels
  MyUtil.drawCleanString("Pressure",bg, f,x_lower/2, (y_lower+y_upper)/2+15,
			 0.5,Color.black,Color.white,0.5);
  MyUtil.drawCleanString("(mb)",bg, f,x_lower/2, (y_lower+y_upper)/2+30,
			 0.5,Color.black,Color.white,0.5);
  
  // clean up top
  bg.setColor(Color.white);
  bg.fillRect(0,0,plot_width,y_upper);
  
  //draw hodograph
  rad_ho = plot_width/8;
  scale_ho = rad_ho/(wind_scale*.8);  //80 kts to the outer radius
  ho_size = 2*rad_ho + 20;
  x_ho = x_lower+ho_size/2;
  y_ho = y_upper+ho_size/2;
  ho_switch_min_x = x_lower+ho_size-50;
  ho_switch_max_x = x_lower+ho_size-4;
  ho_switch_min_y = y_upper+ho_size-20;
  ho_switch_max_y = y_upper+ho_size;
  
  bg.fillRect(x_lower,y_upper,ho_size,ho_size);
  bg.setColor(Color.black);
  bg.drawRect(x_lower,y_upper,ho_size,ho_size);
  bg.setColor(Color.gray);
  bg.drawLine(x_ho-rad_ho,y_ho,x_ho+rad_ho,y_ho);
  bg.drawLine(x_ho,y_ho-rad_ho,x_ho,y_ho+rad_ho);
  int r = rad_ho/4;
  int diag = (int)(0.707*r);
  // 20 kts (or 8)
  bg.drawOval(x_ho-r,y_ho-r,2*r,2*r);
  MyUtil.drawCleanString(
      MyUtil.goodRoundString(.2*wind_scale,0,1e10,"",0),
      bg, f,x_ho-diag,y_ho+diag,0.5,Color.gray,Color.white,0.5);
  //40 kts (or 16)
  r += rad_ho/4;
  diag = (int)(0.707*r);
  bg.drawOval(x_ho-r,y_ho-r,2*r,2*r);
  MyUtil.drawCleanString(
      MyUtil.goodRoundString(.4*wind_scale,0,1e10,"",0),
      bg, f,x_ho-diag,y_ho+diag,0.5,Color.gray,Color.white,0.5);
  //60 kts (or 24)
  r += rad_ho/4;
  diag = (int)(0.707*r);
  bg.drawOval(x_ho-r,y_ho-r,2*r,2*r);
  MyUtil.drawCleanString(
      MyUtil.goodRoundString(.6*wind_scale,0,1e10,"",0),
      bg, f,x_ho-diag,y_ho+diag,0.5,Color.gray,Color.white,0.5);
  //80 kts (or 32)
  r += rad_ho/4;
  diag = (int)(0.707*r);
  bg.drawOval(x_ho-r,y_ho-r,2*r,2*r);
  MyUtil.drawCleanString(
      MyUtil.goodRoundString(.8*wind_scale,0,1e10,"",0),
      bg, f,x_ho-diag,y_ho+diag,0.5,Color.gray,Color.white,0.5);
  
  Font fff = new Font("Dialog",Font.BOLD,12);
  color_ho = new Color(0,175,0);
  MyUtil.drawCleanString("wind (kts)",bg, fff,
			 x_ho - rad_ho,y_ho+rad_ho,
			 0,color_ho,Color.white,0.5);
  //it will no longer be the first load of the buffer.
  first_buffer_load=false; 
  plot_sounding();
}

public void plot_trajectory(double t, double td,double p) {
  load_buffer();
  stp.plot_trajectory(pg,t,td,p);
  String parcel_t_str = MyUtil.goodRoundString(t,-1e10,1e10,"",0);
  String parcel_p_str = MyUtil.goodRoundString(p,0,1200,"",0);
  String log_argument="parcel_t="+parcel_t_str+
                      "&parcel_p="+parcel_p_str;
  Logger logger = new Logger(sp.code_base,
			       SoundingPanel.log_file,log_argument);
}

public void plot_sounding() {
    //pull in the background
    pg.drawImage(background_image,0,0,this);
   //plot the sounding
   stp.plot_sounding(pg);
   //plot sounding titles
   stp.plot_titles(pg);
}



/**;========================================================================
;  FUNCTION TO COMPUTE THE TEMPERATURE (Celsius) OF AIR AT A GIVEN
;  PRESSURE AND WITH A GIVEN MIXING RATIO.
;  Originator:  Andrew F. Loughe  (afl@cdc.noaa.gov)
;               CIRES/NOAA
;               Boulder, CO  USA
;               This code carries no warranty or claim
;               as to its usefulness or accuracy!
;
;  A Number of the functions found in this file were converted from
;  FORTRAN code that was received from NCAR in Boulder, CO USA.
;  The original source of the equations is thought to be:
;    "Algorithms for Generating a Skew-T, Log P Diagram
;     and Computing Selected Meteorological Quantities"
;     by G.S. Stipanuk, White Sands Missle Range, Report ECOM-5515.
;*/

public double tmr(double wv,double p) {
    double x = 0.4343 * Math.log(wv * p /(622. + wv));
    double tmr = Math.pow(10,.0498646455 * x + 2.4082965 ) - 7.07475
                 + 38.9114 * Math.pow((Math.pow(10, .0915 * x) - 1.2035),2);
    return (tmr - K0);
}

/**
*override the standard to avoid clearing the screen
*/
public void update(Graphics g) {
  paint(g);
}

/**
* draws an off screen image from the parent onto the screen.
*/
public void paint(Graphics g) {
  g.drawImage(plot_image, 0, 0, this);
  if(dragging) {
    g.setColor(Color.red);
    g.drawRect(zoom_x1,zoom_y1,zoom_x_range,zoom_y_range);
  } else {
    //now draw the data at the mouse location, if relevant
    stp.plot_values(g,mouse_pt);
  }
}

public void mousePressed(MouseEvent e) {
  Point p = new Point(e.getX(),e.getY());
  start_mouse_pt = p;
}

public void mouseDragged(MouseEvent e) {
  int x = e.getX();
  int y = e.getY();
  mouse_pt = new Point(x,y);
  dragging=true;
  //we are zooming.  give paint a rectangle to show zoom region
  //it should have the same aspect ratio as the window
  zoom_x_range=(int)Math.abs(x-start_mouse_pt.x);
  int y_range_1=(int)(aspect_ratio*zoom_x_range);
  int y_range_2=(int)Math.abs(y-start_mouse_pt.y);
  if(y_range_2>y_range_1) {
    //y-distance determines size
    zoom_y_range=y_range_2;
    zoom_x_range=(int)(zoom_y_range/aspect_ratio);
  } else {
    //x-distance determines size
    zoom_y_range = y_range_1;
  }
  if(x > start_mouse_pt.x) {
    zoom_x1 = start_mouse_pt.x;
  } else {
    zoom_x1 = start_mouse_pt.x - zoom_x_range;
  }
  if(y > start_mouse_pt.y) {
    zoom_y1 = start_mouse_pt.y;
  } else {
    zoom_y1 = start_mouse_pt.y - zoom_y_range;
  }
  repaint();
}

public void mouseReleased(MouseEvent e) {
  String log_argument;
  Logger logger;
  int x = e.getX();
  int y = e.getY();
  //dont rescale if the zoom is too small
  if(dragging && zoom_x_range > 20) {
    mouseDragged(e);
    //get new limits
    int yy = zoom_y1+zoom_y_range;
    int xx = zoom_x1+zoom_x_range;
    // upper right
    get_thermo(xx,zoom_y1,thp);
    p_ur = thp.pr;
    // lower right
    get_thermo(xx,yy,thp);
    t_lr = thp.t;
    p_lr = thp.pr;
    theta_lr = thp.theta;
    // lower left
    get_thermo(zoom_x1,yy,thp);
    t_ll = thp.t;
    theta_ll = thp.theta;
    set_mapping();
    sp.p_scale_btn.setLabel(sp.str_150mb);
    load_buffer();
    repaint();
    String plo_str = MyUtil.goodRoundString(p_lr,0,1200,"",0);
    String pup_str = MyUtil.goodRoundString(p_ur,0,1200,"",0);
    String tmin_str = MyUtil.goodRoundString(t_ll,-500,1200,"",0);
    String tmax_str = MyUtil.goodRoundString(t_lr,-500,1200,"",0);
    log_argument="p_lr="+plo_str+"&p_ur="+pup_str+
      "&t_ll="+tmin_str+"&t_lr="+tmax_str;
    logger = new Logger(sp.code_base,
                               sp.log_file,log_argument);
  } else if(x > ho_switch_min_x && x < ho_switch_max_x &&
	    y > ho_switch_min_y && y < ho_switch_max_y) {
    // toggle whether we want flight track or hodograph
    want_hodo = ! want_hodo;
    boolean track= ! want_hodo;
    log_argument="track="+track;
    logger = new Logger(sp.code_base,sp.log_file,log_argument);
    load_buffer();
    repaint();
  } else {
    //no drag, so draw a trajectory of a lifted parcel from here
    get_thermo(x,y,thp);
    t = thp.t;
    p = thp.pr;
    td = Sounding.MISSING; //plot_trajectory will calculate
    if(e.isMetaDown()) {
      //ask the user for the dewpoint, temp, and pressure
      Point s_loc = getLocationOnScreen();
      new ChooseDewpoint(this,s_loc.x+x,s_loc.y+y);
    } else {
      plot_trajectory(t,td,p);
      repaint();
    }
  }
  dragging=false;
}

public void mouseMoved(MouseEvent e) {
  if(Sounding.n_soundings_to_plot > 0) {
    mouse_pt = new Point(e.getX(),e.getY());
    SoundingLevel lev = stp.get_level(mouse_pt);
    repaint();
  }
}

public void warn(String warning) {
  pg.setColor(Color.red);     // may need this for Explorer(?)
  pg.fillRect(0,0,plot_width,plot_height);
  Font val_font = new Font("Helvetica", Font.BOLD, 18);
  sp.reset_buttons();
  MyUtil.drawCleanString(warning,pg,val_font,plot_width/2,
                            plot_height/2,
                            0.5,Color.black,Color.white);
  warning = "Use the buttons below to display or load another";
  MyUtil.drawCleanString(warning,pg,val_font,plot_width/2,plot_height/2 + 20
                            ,0.5,Color.black,Color.white);
}

// keep the MouseListener interface happy
public void mouseExited(MouseEvent e) {}
public void mouseClicked(MouseEvent e) {}
public void mouseEntered(MouseEvent e) {}

} //end of class SoundingCanvas
