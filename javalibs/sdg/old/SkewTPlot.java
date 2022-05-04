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
import java.awt.image.ImageProducer;
import java.applet.Applet;
import java.util.*;
import java.io.*;
import java.lang.System;
import java.lang.Runtime;
import java.net.*;

/**
*  Class SkewTPlot
* change details
* 15-Jul-2002 - increased the spacing between line 1 and line 2 of the
*               title (2 lines used for ACARSSounding)
*
* 11-May-2004 - moved information by cursor a little further down so
*               it doesn't obscure dewpoint information.
*
*/
public class SkewTPlot {
  static Color sounding_color[] = new Color[100];
  static Color far_color = Color.gray;
  static Color baro_color = new Color(255,153,0);
  ThermoPack thp = new ThermoPack(0,0,0);
  Point p1 = new Point(0,0);	// used for temporary storage
  Point p2 = new Point(0,0);
  SoundingCanvas sc;
  int point_size;
  int barb_scale;
  Font load_font;
  FontMetrics load_fm;
  Font val_font;
  FontMetrics val_fm;
  Font cursor_font;
  FontMetrics cursor_fm;
  Font thermo_font;
  boolean fonts_set=false;
  double MAX_DIST = 100.;
  boolean plot_flight_track = false; // true to plot flt trk not hodo
  boolean has_flight_track = false; // true if sounding has flt trk
  int yp = 0;			// location for plotting thermo info
  int y_inc;
  Font fff = new Font("Dialog",Font.BOLD,12);
  Font ffr = new Font("Dialog",Font.PLAIN,12);


public SkewTPlot (SoundingCanvas sc) {
        this.sc = sc;
        val_font = new Font("Helvetica", Font.BOLD, 12);
	cursor_font = new Font("Helvetica", Font.PLAIN, 12);
        load_font = new Font("Helvetica",Font.BOLD, 16);
	y_inc = 15;
	yp = 0;
	yp = sc.y_upper+10;

        //other values
        point_size=7;
        barb_scale = (int)(5*point_size);
        sounding_color[4]=new Color(255,165,204);
        sounding_color[3]=new Color(0,153,0);
        sounding_color[2]=new Color(255,110,1);
        sounding_color[1]=new Color(255,0,255);
	sounding_color[0]=Color.black;
}

public SoundingLevel get_level(Point p) {
  int current_index = Sounding.soundings_to_plot[0];
  Sounding s = sc.sp.sounding[current_index];
  int i;
  SoundingLevel lev = null;  //presets lev.p to zero
  SoundingLevel lev_to_return = null;
  //double press = sc.get_press(y);
  sc.get_thermo(p.x,p.y,thp);
  double press = thp.pr;
  double last_p_dist = 1e10;
  double p_dist = 1e10;
  if(press <= sc.p_lr && press >= sc.p_ur-1) {
    for(i=0;i<s.n_levels;i++) {
      lev = (SoundingLevel)s.level.elementAt(i);
      p_dist = Math.abs(lev.p - press);
      if(p_dist > last_p_dist) {
	break;
      }
      last_p_dist = p_dist;
      lev_to_return = lev;
    }
  }
  return lev_to_return;
}

public void plot_values(Graphics g, Point m) {
    if(! fonts_set) {
        val_fm=g.getFontMetrics(val_font);
        load_fm = g.getFontMetrics(load_font);
	cursor_fm = g.getFontMetrics(cursor_font);	
        g.setFont(val_font);
        fonts_set=true;
    }

    if(sc.sp.loading_soundings) {
        int x = sc.x_lower+5;
        int y = sc.y_lower - 20;
        String val = "Loading data...";
         //int val_width = load_fm.stringWidth(val);
        //int val_height = load_fm.getHeight();
        MyUtil.drawCleanString(val,g,load_font,x,y,0,Color.black,Color.yellow);
     }
    if(Sounding.n_soundings_to_plot > 0) {
      Sounding s =
	sc.sp.sounding[Sounding.soundings_to_plot[0]];
      SoundingLevel lev = get_level(m);
      if(lev != null && sc.is_on_plot(m)) {
	sc.get_xy(lev.p,lev.t,p1);
	
	//write values
	g.setColor(Color.black);
	String val;
	//int val_width;
	double center_fact = 0.3;
	int x,y;
	int line_length=10;
	int line_thick=3;
	
	//write pressure  and height on the left
	x=sc.x_lower+5;
	y = sc.get_y(lev.p,x);
	if(lev.z != Sounding.MISSING) {
	  String val_p=MyUtil.goodRoundString(lev.p,0.,1.e10,"",0);
	  double z_ft = lev.z/0.3048;
	  String val_z =MyUtil.goodRoundString(z_ft,-1.e10,1.e10,"",0);
	  double z_km = lev.z/1000;
	  String val_km = MyUtil.goodRoundString(z_km,-1.e10,1e10,"",1);
	  val = val_p+"mb ("+val_km+" km)";
	  MyUtil.drawCleanString(val,g,val_font,x,y,
				 0,Color.black,Color.white,0);
	  val = val_z+" ft";
	  String val_z_agl = "";
	  if(lev.z_gps < Sounding.MISSING - 1 &&
	     s.station_elev < Sounding.MISSING - 1) {
	    val_z_agl =
	      MyUtil.goodRoundString(lev.z_gps/0.3048 - s.station_elev,
				     -1.e10,1.e10,"",0);
	    val += " (agl: "+val_z_agl+")";
	  }
	  MyUtil.drawCleanString(val,g,val_font,x,y,
				 0,Color.black,Color.white,1);
	  //add bearing/range/time if it exists
	  if(lev.bearing != Sounding.MISSING) {
	    String val_b = MyUtil.goodRoundString(lev.bearing,0,360,"",0);
	    String val_r = MyUtil.goodRoundString(lev.range,0,1.e10,"",0);
	    String val_time = lev.date.getHHMM();
	    val = "   B/R: "+val_b+"\u00b0/"+val_r+" "+val_time+"Z";
	    MyUtil.drawCleanString(val,g,val_font,x,y,
				   0,Color.black,Color.white,2);
	  }
	} else {
	  String val_p=MyUtil.goodRoundString(lev.p,0.,1.e10,"",0);
	  val = val_p+"mb";
	  MyUtil.drawCleanString(val,g,val_font,x,y,
				 0,Color.black,Color.white,0);
	}
	
	//indicate the pressure level
	draw_thick_line(g,line_thick,sc.x_lower,y,
			sc.x_lower+line_length,y);
	
	//write dewpoint near that line
	sc.get_xy(lev.p,lev.dp,p1);
	val=MyUtil.goodRoundString(lev.dp,-100.,32000,"",1);
	if(! val.equals("")) {
	  //data not missing
	  // get relative humidity in percent
	  double rh = Stability.satVapPres(lev.dp + 273.15) /
	    Stability.satVapPres(lev.t + 273.15) * 100;
	  val +=
	    " ("+
	    MyUtil.goodRoundString(rh,0,100,"",0)+
	    "%)";
	  
	  if(lev.p > 750) {
	    double tf = lev.dp*1.8 + 32.;
	    String val_tf = MyUtil.goodRoundString(tf,-200.,200,"",0);
	    val += " ("+val_tf+" F)";
	  }
	  x = p1.x-10;
	  MyUtil.drawCleanString(val,g,val_font,x,p1.y,
				 1,Color.black,Color.white,1);
	  draw_thick_line(g,line_thick,p1.x-line_length/2,p1.y,
			  p1.x+line_length/2,p1.y);
	}

	//write temperature near that line
	sc.get_xy(lev.p,lev.t,p1);
	val=MyUtil.goodRoundString(lev.t,-100.,32000,"",1);
	if(! val.equals("")) {
	  //add farenheit if below 750 mb altitude
	  if(lev.p > 750) {
	    double tf = lev.t*1.8 + 32.;
	    String val_tf = MyUtil.goodRoundString(tf,-200.,200,"",0);
	    val += " ("+val_tf+" F)";
	  }
	  //val_width = val_fm.stringWidth(val);
	  x = p1.x+10;
	  MyUtil.drawCleanString(val,g,val_font,x,p1.y,
				 0,Color.black,Color.white,0);
	  draw_thick_line(g,line_thick,p1.x-line_length/2,p1.y,
			  p1.x+line_length/2,p1.y);
	}
	
	//write the wind near the right side
	String val_ws=MyUtil.goodRoundString(lev.ws,0,32000,"",0);
	String val_wd=MyUtil.goodRoundString(lev.wd,0,359,"",0);
	float item;
	if(lev.wd < 32000) {
	  val=val_wd+"\u00b0/"+val_ws;
	  x = sc.x_upper - 5;
	  y = sc.get_y(lev.p,x);
	  MyUtil.drawCleanString(val,g,val_font,x,y,
				 1,Color.black,Color.white,1);
	  draw_thick_line(g,line_thick,sc.x_upper-line_length,y,
			  sc.x_upper,y);

	  // get the right size y for this pressure
	  y = sc.get_y(lev.p,sc.x_upper);
	  //redraw a wind barb
	  //erase the old barb
	  Barb.plot(g,sc.x_barb,y,lev.wd,lev.ws,
		    barb_scale,point_size,Color.white,s.station_lat);
	  //and draw a bigger one in black
	  Barb.plot(g,sc.x_barb,y,lev.wd,lev.ws,
		    (int)(1.5*barb_scale),
		    (int)(1.5*point_size),Color.black,s.station_lat);
	  
	  //re-plot part of the wind speed plot
	  g.setColor(Color.red);
	  int i = lev.n_level;
	  //find next level with good data
	  //dummy assignment to keep compiler happy
	  SoundingLevel next_lev = lev;
	  boolean next_good_level=false;
	  for(int j = i+1;j<s.n_levels;j++) {
	    next_lev = (SoundingLevel)s.level.elementAt(j);
	    if(next_lev.ws != Sounding.MISSING) {
	      next_good_level=true;
	      break;
	    }
	  }
	  if(next_good_level) {
	    p1.x = (int)(sc.speed_to_x*lev.ws) + sc.x_barb;
	    p1.y = sc.get_y(lev.p,sc.x_upper);
	    p2.x = (int)(sc.speed_to_x*next_lev.ws) + sc.x_barb;
	    p2.y = sc.get_y(next_lev.p,sc.x_upper);
	    int thick = 2;
	    draw_thick_line(g,thick,p1.x,p1.y,p2.x,p2.y);
	  }
	}  //jump here if wind is missing
	
	//re-draw part of hodograph/flight track
	boolean plot_this=true;
	if(plot_flight_track) {
	  item = lev.range;
	} else {
	  item = lev.ws;
	}
	if(item != Sounding.MISSING) {
	  boolean next_good_level=false;
	  int i = lev.n_level;
	  SoundingLevel next_lev = lev;
	  for(int j = i+1;j<s.n_levels;j++) {
	    next_lev = (SoundingLevel)s.level.elementAt(j);
	    if(plot_flight_track) {
	      item = next_lev.range;
	      if(item != Sounding.MISSING && item > MAX_DIST) {
		break;
	      }
	    } else {
	      item = next_lev.ws;
	    }
	    if(item != Sounding.MISSING) {
	      next_good_level=true;
	      break;
	    }
	  }
	  if(next_good_level) {
	    // both lev and next_lev are good
	    //redraw part of hodograph
	    double u1,v1,u2,v2;
	    if(plot_flight_track) {
	      u1 = lev.range*Math.sin(lev.bearing/57.3);
	      v1 = lev.range*Math.cos(lev.bearing/57.3);
	      u2 = next_lev.range*Math.sin(next_lev.bearing/57.3);
	      v2 = next_lev.range*Math.cos(next_lev.bearing/57.3);
	      if(next_lev.range > sc.wind_scale) {
		plot_this=false;
	      }
	    } else {
	      u1 = -lev.ws*Math.sin(lev.wd/57.3);
	      v1 = -lev.ws*Math.cos(lev.wd/57.3);
	      u2 = -next_lev.ws*Math.sin(next_lev.wd/57.3);
	      v2 = -next_lev.ws*Math.cos(next_lev.wd/57.3);
	    }
	    if(plot_this) {
	      int x1,x2,y1,y2;
	      x1 = (int)(sc.x_ho + sc.scale_ho * u1);
	      y1 = (int)(sc.y_ho - sc.scale_ho * v1);
	      x2 = (int)(sc.x_ho + sc.scale_ho * u2);
	      y2 = (int)(sc.y_ho - sc.scale_ho * v2);
	      draw_thick_line(g,4,x1,y1,x2,y2);
	    }
	  }
	}
	// end of hodograph/flight track section
      }
      //write the current pressure and temperature at the cursor
      int pix_below = 15;
      if(sc.is_on_plot(m)) {
	sc.get_thermo(m.x,m.y,thp);
	double t = thp.t;
	double press = thp.pr;
	double th = thp.theta;
	String ths = MyUtil.goodRoundString(th,-1e10,1e10,"?",1);
	// \u03B8 is the theta symbol (but not on MACs!!
	MyUtil.drawCleanString("\u03B8: "+ths,g,cursor_font,
			       m.x-60,m.y+pix_below,
			       0,Color.black,Color.white,1);
	double tf = t*1.8 + 32.;
	String val_tf = MyUtil.goodRoundString(tf,-200.,200,"",0);
	String val_t = MyUtil.goodRoundString(t,-150,150,"",1);
	String val_p = MyUtil.goodRoundString(press,0,1500,"",1);
	String val = "T: "+val_t+" ("+val_tf+"F), "+val_p+"mb ";
	double z_ft = Sounding.getAltitude(press);
	String val_z = MyUtil.goodRoundString(z_ft,-1.e10,1.e10,"",0)
	  +" ft.";
	int val_width = cursor_fm.stringWidth(val_z);
	int right_side = m.x + val_width + 15;
	MyUtil.drawCleanString(val_z,g,cursor_font,right_side,m.y+pix_below,
			       1,Color.black,Color.white,1);	   
	MyUtil.drawCleanString(val,g,cursor_font,m.x-60,m.y+pix_below+13,
			       0,Color.black,Color.white,1);
	/* for testing
	   int ypix = sc.get_y(thp.pr,m.x);
	   MyUtil.drawCleanString(ypix+"/"+m.y,g,cursor_font,right_side,
	   m.y+30,1,Color.black,Color.white,1);
	*/
      }
    }
}
  

public void draw_thick_line(Graphics g, int thick,int x1,int y1,
				int x2,int y2) {
        boolean horizontal=false;
        if(Math.abs(y2-y1) < Math.abs(x2-x1)) {
           horizontal=true;
        }
        int j = -thick/2 - 1;
        if(horizontal) {
            for(int i=0;i<thick;i++) {
                j++;
                g.drawLine(x1,y1+j,x2,y2+j);
            }
        } else {
            for(int i=0;i<thick;i++) {
                j++;
                g.drawLine(x1+j,y1,x2+j,y2);
            }
        }
    }

public void plot_titles(Graphics g) {
        if(Sounding.n_soundings_to_plot > 0) {
            Font val_font = new Font("Helvetica", Font.PLAIN, 14);
            g.setFont(val_font);
            FontMetrics val_fm=g.getFontMetrics(val_font);
            int val_height = val_fm.getHeight();
            //g.setColor(Color.red);
            //int k=0;
            for(int i=0;i<Sounding.n_soundings_to_plot;i++) {
                int sounding_index=
                  Sounding.soundings_to_plot[i];
		Color this_color=sounding_color[i];
                String title = ""+
		  sc.sp.sounding[sounding_index].getModelString();
                MyUtil.draw_clean_string(title,g, val_font,
					 25,sc.y_lower -5 +
					 (int)((2-i)*val_height),
					 0,this_color,Color.white);
                //k++;
            }
            if(Sounding.n_soundings_to_plot == 1) {
             //add a more detailed title at the top.
            String[] long_title =
              sc.sp.sounding[Sounding.soundings_to_plot[0]].getLongTitle();
            MyUtil.draw_clean_string(long_title[0],g,val_font,
				  (sc.x_lower + sc.x_upper)/2,sc.y_upper-5,.5,
                                          Color.black,Color.white);
           if(long_title.length > 1) {
                MyUtil.draw_clean_string(long_title[1],g,val_font,
                            (sc.x_lower + sc.x_upper)/2,sc.y_upper+14,.5,
                                          Color.black,Color.white);
           }
            }
         }
    }

public void plot_sounding(Graphics g) {
  boolean any_good_levs;
  Color t_color,dp_color,b_color,ws_color;
  int thick;
  int this_sounding_index;
  Sounding s;
  
  if(Sounding.n_soundings_to_plot > 0) {
    for(int j=Sounding.n_soundings_to_plot-1;j>=0;j--) {
      this_sounding_index = Sounding.soundings_to_plot[j];
      s = sc.sp.sounding[this_sounding_index];
      //choose colors
      t_color=sounding_color[j];
      dp_color=sounding_color[j];
      b_color=sounding_color[j];
      ws_color=sounding_color[j];
      if(Sounding.n_soundings_to_plot == 1) {
	//use multi colors if only plotting 1 sounding
	t_color=Color.red;
	dp_color=Color.blue;
	b_color=Color.red;
	ws_color=Color.blue;
      }
      thick=3;
      //keep the compiler happy
      SoundingLevel lev = (SoundingLevel) s.level.elementAt(0);
      
      // PLOT DEWPOINT
      //find lowest level with dewpoint
      any_good_levs = false;
      int i1=0;
      int i2=0;
      for(int i=0;i<s.n_levels;i++) {
	lev = (SoundingLevel) s.level.elementAt(i);
	if(lev.dp != Sounding.MISSING) {
	  any_good_levs=true;
	  i1 = i;
	  break;
	}
      }
      if(any_good_levs) {
        sc.get_xy(lev.p,lev.dp,p1);
	boolean too_far = false;
        for(int i=i1+1;i<s.n_levels;i++) {
	  lev = (SoundingLevel)s.level.elementAt(i);
	  if(lev.p < sc.p_ur) {
	    break;
	  }
	  if(lev.range != Sounding.MISSING && lev.range > MAX_DIST) {
	    too_far = true;
	  }
	  if(lev.dp != Sounding.MISSING) {
	    sc.get_xy(lev.p,lev.dp,p2);
	    i2 = i;
	    // for Aircraft data, levels must be adjacent
	    if(lev.date == null || // non-Aircraft data, or
	       i2 - i1 == 1) {     // adjacent levels
	      // plot a line segment
	      g.setColor(dp_color);
	      if(too_far) {
		g.setColor(far_color);
	      } else if(j == 0 && lev.dpUnc == Sounding.INF_DP_UNCERTAINTY) {
		g.setColor(baro_color);
	      }
	      if(sc.is_on_plot(p2) && sc.is_on_plot(p1)) {
		draw_thick_line(g,thick,p1.x,p1.y,p2.x,p2.y);
	      }
	    }
	    // keep p1 and p2 separate memory locations
	    p1.x=p2.x;
	    p1.y=p2.y;
	    i1 = i2;
	  }
        }
      }

      // PLOT TEMPERATURE
      g.setColor(t_color);
      //find lowest level with temperature
      any_good_levs = false;
      for(int i=0;i<s.n_levels;i++) {
	lev = (SoundingLevel) s.level.elementAt(i);
	if(lev.t != Sounding.MISSING) {
	  any_good_levs=true;
	  break;
	}
      }
      if(any_good_levs) {
        sc.get_xy(lev.p,lev.t,p1);
	boolean too_far = false;
        for(int i=1;i<s.n_levels;i++) {
	  lev = (SoundingLevel)s.level.elementAt(i);
	  if(lev.p < sc.p_ur) {
	    break;
	  }
	  if(lev.range != Sounding.MISSING && lev.range > MAX_DIST) {
	    too_far = true;
	  }
	  if(lev.t != Sounding.MISSING) {
	    g.setColor(t_color);
	    if(too_far) {
	      g.setColor(far_color);
	    } else if(j == 0 && lev.data_descriptor > 3) {
	      // we are using baroAltitude instead of altitude
	      g.setColor(baro_color);
	    }
	    sc.get_xy(lev.p,lev.t,p2);
	    if(sc.is_on_plot(p2) && sc.is_on_plot(p1)) {
	      draw_thick_line(g,thick,p1.x,p1.y,p2.x,p2.y);
	    }
	    // keep p1 and p2 separate memory locations
	    p1.x=p2.x;
	    p1.y=p2.y;
	  }
        }
      }

      // plot icing, if it exists
      for(int i=1;i<s.n_levels;i++) {
	lev = (SoundingLevel)s.level.elementAt(i);
	if(lev.p < sc.p_ur) {
	  break;
	}
	if(lev.ice > 0) {
     	  int x = sc.x_upper - 5;
	  int y = sc.get_y(lev.p,x);
	  MyUtil.drawCleanString("ice",g,val_font,x,y,
				 1,Color.red,Color.white,1);
	}
      }

      //plot barbs
      Color c = b_color;
      for(int i=0;i<s.n_levels;i++) {
	lev = (SoundingLevel)s.level.elementAt(i);
	if(lev.p < sc.p_ur) {
	  break;
	}
	if(lev.wd != Sounding.MISSING) {
	  if(lev.range != Sounding.MISSING &&
	     lev.range > MAX_DIST) {
	    //g.setColor(far_color);
	    c = far_color;
	  }
	  sc.get_xy(lev.p,lev.t,p1);  //the second arg doesnt matter
	  int y = sc.get_y(lev.p,sc.x_upper);
	  Barb.plot(g,sc.x_barb,y,lev.wd,lev.ws,
		    barb_scale,point_size,c,s.station_lat);
	}
      }

      //plot wind speed on right and on hodograph
      //find lowest level with wind speed
      any_good_levs = false;
      plot_flight_track = false;
      has_flight_track = false;
      for(int i=0;i<s.n_levels;i++) {
	lev = (SoundingLevel) s.level.elementAt(i);
	if(lev.bearing != Sounding.MISSING) {
	  has_flight_track=true;
	  if(!sc.want_hodo) {
	    plot_flight_track = true;
	  }
	}
	if(lev.ws != Sounding.MISSING) {
	  any_good_levs=true;
	  break;
	}
      }
      if(any_good_levs == true ||
	 plot_flight_track) {
        double u1,v1,u2,v2;
        int x1,y1,x2,y2;
        Font f = new Font("Dialog",Font.BOLD,14);
        //sc.get_xy(lev.p,lev.dp,p1);  //second argument doesnt matter
        p1.x = (int)(sc.speed_to_x*lev.ws) + sc.x_barb;
	p1.y = sc.get_y(lev.p,sc.x_upper);
        //get u and v for hodograph, or flight track
        int last_label_ht = -1;
	if(plot_flight_track) {
	  // bearing/range
	  u1 = lev.range*Math.sin(lev.bearing/57.3);
	  v1 = lev.range*Math.cos(lev.bearing/57.3);
	} else {
	  // wind speed
	  u1 = -lev.ws*Math.sin(lev.wd/57.3);
	  v1 = -lev.ws*Math.cos(lev.wd/57.3);
	}
	boolean plot_on_hodo = true; // indicates end of hodo or flt trk plt
        for(int i=1;i<s.n_levels;i++) {
	  lev = (SoundingLevel)s.level.elementAt(i);
	  if(lev.p < sc.p_ur) {
	    break;
	  }
	  if((plot_flight_track && lev.bearing != Sounding.MISSING) ||
	     (!plot_flight_track && lev.ws != Sounding.MISSING)) {
	    //right-side plot
	    if(lev.ws != Sounding.MISSING) { // wrm 5/21/03
	      //sc.get_xy(lev.p,lev.dp,p2);
	      p2.x = (int)(sc.speed_to_x*lev.ws) + sc.x_barb;
	      p2.y = sc.get_y(lev.p,sc.x_upper);
	      thick=2;
	      g.setColor(ws_color);
	      if(lev.range != Sounding.MISSING &&
		 lev.range > MAX_DIST) {
		g.setColor(far_color);
	      }
	      draw_thick_line(g,thick,p1.x,p1.y,p2.x,p2.y);
	      // keep p1 and p2 separate memory locations
	      p1.x=p2.x;
	      p1.y=p2.y;
	    }
	    //hodograph or flight track
	    if(plot_flight_track) {
	      // a kludge: use the wind_scale to cut off the
	      // flight track plot, 'cuz we use the same scale
	      // for both the track and the hodograph
	      // bearing/range
	      u2 = lev.range*Math.sin(lev.bearing/57.3);
	      v2 = lev.range*Math.cos(lev.bearing/57.3);
	      if(lev.range > sc.wind_scale) {
		plot_on_hodo=false;
	      }
	    } else  {
	      u2 = -lev.ws*Math.sin(lev.wd/57.3);
	      v2 = -lev.ws*Math.cos(lev.wd/57.3);
	      if(lev.ws > sc.wind_scale) {
		plot_on_hodo = false;
	      }
	    }
	    if(plot_on_hodo) {
	      if(Sounding.n_soundings_to_plot == 1) {
		g.setColor(sc.color_ho);
	      } else {
		g.setColor(ws_color);
	      }
	      if(lev.range != Sounding.MISSING &&
		 lev.range > MAX_DIST) {
		g.setColor(far_color);
	      }
	      x1 = (int)(sc.x_ho + sc.scale_ho * u1);
	      y1 = (int)(sc.y_ho - sc.scale_ho * v1);
	      x2 = (int)(sc.x_ho + sc.scale_ho * u2);
	      y2 = (int)(sc.y_ho - sc.scale_ho * v2);
	      //hodograph label every 3 km
	      if(!plot_flight_track) {
		int this_label_ht = (int)(lev.z/3000);
		if(j == 0 && this_label_ht != last_label_ht) {
		  last_label_ht = this_label_ht;
		  String val = MyUtil.goodRoundString(lev.z/1000,0,100,"",0);
		  MyUtil.drawCleanString(val,g,f,x2,y2,
					 0.5,Color.gray,null,0.5);
		}
	      }
	      draw_thick_line(g,thick,x1,y1,x2,y2);
	      u1 = u2;
	      v1=v2;
	    }
	  }
	}
      } //end wind speed section
      
      // label the hodograph /flight track window
      if(plot_flight_track) {
	MyUtil.drawCleanString("nm from Airport",g, fff,
			       sc.x_ho - sc.rad_ho,sc.y_ho+sc.rad_ho,
			       0,sc.color_ho,Color.white,0.5);
      }
      
      // creat a fake "button" if necessary
      if(has_flight_track) {
	MyUtil.drawCleanString("Toggle",g,ffr,
			       sc.ho_switch_max_x,
			       sc.ho_switch_max_y,
			       1,Color.black,Color.lightGray);
      }
      
      //themodynamic variables
      thermo_font = new Font("Dialog",Font.BOLD,12);
      yp = sc.y_upper+10;
      if(j == 0) {
	if(s.CAPE != Sounding.MISSING) {
	  String var = "CAPE "+
	    MyUtil.goodRoundString(s.CAPE,0,1e10,"",0);
	  MyUtil.drawCleanString(var,g,thermo_font,sc.x_upper-10,yp,
				 1,Color.black,Color.white,1);
	  yp += y_inc;
	}
	if(s.CIn != Sounding.MISSING) {
	  String var = "CIn "+
	    MyUtil.goodRoundString(s.CIn,-1.e10,1e10,"",0);
	  MyUtil.drawCleanString(var,g,thermo_font,sc.x_upper-10,yp,
				 1,Color.black,Color.white,1);
	  yp += y_inc;
	}
	if(s.PW != Sounding.MISSING) {
	  String var = "PW "+
	    MyUtil.goodRoundString(s.PW,0,1e10,"",0);
	  MyUtil.drawCleanString(var,g,thermo_font,sc.x_upper-10,yp,
				 1,Color.black,Color.white,1);
	  yp += y_inc;
	}
	if(s.Helic != Sounding.MISSING) {
	  String var = "Helic (m^2/s^2) = "+
	    MyUtil.goodRoundString(s.Helic,-1.e10,1e10,"",0);
	  MyUtil.drawCleanString(var,g,thermo_font,sc.x_upper-10,yp,
				 1,Color.black,Color.white,1);
	  yp += y_inc;
	}
	if(s.TotalTotals != Sounding.MISSING) {
	  String var = "TT "+
	    MyUtil.goodRoundString(s.TotalTotals,-1.e10,1e10,"",0);
	  MyUtil.drawCleanString(var,g,thermo_font,sc.x_upper-10,yp,
				 1,Color.black,Color.white,1);
	  yp += y_inc;
	}
	if(s.KIndex != Sounding.MISSING) {
	  String var = "KI "+
	    MyUtil.goodRoundString(s.KIndex,-1.e10,1e10,"",0);
	  MyUtil.drawCleanString(var,g,thermo_font,sc.x_upper-10,yp,
				 1,Color.black,Color.white,1);
	  yp += y_inc;
	}
	if(s.LiftedIndex != Sounding.MISSING) {
	  String var = "LI "+
	    MyUtil.goodRoundString(s.LiftedIndex,-1.e10,1e10,"",0);
	  MyUtil.drawCleanString(var,g,thermo_font,sc.x_upper-10,yp,
				 1,Color.black,Color.white,1);
	  yp += y_inc;
	}
	if(s.Showalter != Sounding.MISSING) {
	  String var = "SI "+
	    MyUtil.goodRoundString(s.Showalter,-1.e10,1e10,"",0);
	  MyUtil.drawCleanString(var,g,thermo_font,sc.x_upper-10,yp,
				 1,Color.black,Color.white,1);
	  yp += y_inc;
	}
	if(s.Sweat != Sounding.MISSING) {
	  String var = "SW "+
	    MyUtil.goodRoundString(s.Sweat,-1.e10,1e10,"",0);
	  MyUtil.drawCleanString(var,g,thermo_font,sc.x_upper-10,yp,
				 1,Color.black,Color.white,1);
	  yp += y_inc;
	}
	if(s.ParcelLCL != Sounding.MISSING) {
	  String var = "LCL "+
	    MyUtil.goodRoundString(s.ParcelLCL,-1.e10,1e10,"",0);
	  MyUtil.drawCleanString(var,g,thermo_font,sc.x_upper-10,yp,
				 1,Color.black,Color.white,1);
	  yp += y_inc;
	}
	if(s.LFC != Sounding.MISSING) {
	  String var = "LFC "+
	    MyUtil.goodRoundString(s.LFC,-1.e10,1e10,"",0);
	  MyUtil.drawCleanString(var,g,thermo_font,sc.x_upper-10,yp,
				 1,Color.black,Color.white,1);
	  yp += y_inc;
	}
	if(s.EquibPressureLevel != Sounding.MISSING) {
	  String var = "EL "+
	    MyUtil.goodRoundString(s.EquibPressureLevel,
				   -1.e10,1e10,"",0);
	  MyUtil.drawCleanString(var,g,thermo_font,sc.x_upper-10,yp,
				 1,Color.black,Color.white,1);
	  yp += y_inc;
	}
      }
      
    } //end loop over soundings
  } // end n_soundings > 0
}
  
/**
 * Plot a trajectory
 */
public void plot_trajectory(Graphics g,
			    double t_start, double td_start,
			    double pr_start) {
  if(Sounding.n_soundings_to_plot > 0) {
    Sounding s = sc.sp.sounding[Sounding.soundings_to_plot[0]];
    // if we are lower than the lowest level, return
    Stability sta = s.sta;	// syntactic sugar
    Debug.println("Found a sta for this sounding");
    // find the level in the Stability function that corresponds to this
    int start_lev = -1;
    for(int i=0;i<sta.n_levels;i++) {
      if(pr_start > sta.pres[i]) {
	start_lev = i;
	break;
      }
    }
    if(start_lev == -1) {
      return;
    }
    //clear out old parcel information
    for(int i=0;i<sta.n_levels;i++) {
      sta.parcel_temp[i]=Sounding.MISSING;
      sta.CACIn_flag[i]=0;
    }

    // get stating point to plot
    sc.get_xy(pr_start,t_start,p1);
    double t_this=Sounding.MISSING;
    double t_last = t_start;
    double pr_last = pr_start;
    double pr_this=0;
    double pte=0;
    if(td_start == Sounding.MISSING &&
       sta.dewpt[start_lev] != Sounding.MISSING ) {
      Debug.println("start_lev is "+start_lev+", dewpt is "+
		    sta.dewpt[start_lev]);
      td_start = sta.dewpt[start_lev]-273.15;
    }
    Debug.println("td_start is "+td_start);
    if(td_start == Sounding.MISSING) {
      //need to request a dewpoint
      Point s_loc = sc.getLocationOnScreen();
      sc.get_xy(pr_start,t_start,p1);
      new ChooseDewpoint(sc,s_loc.x+p1.x,s_loc.y+p1.y);
      return;
    }
    if(td_start > t_start) {
      td_start = t_start;
    }
    // get LCL for this point
    double LCL = sta.pressureAtLCL(t_start+273.15,td_start+273.15,
				   pr_start);
    // plot the line
    boolean past_LCL=false;
    g.setColor(new Color(255,0,255));
    for(int i=start_lev;i<sta.n_levels;i++) {
      if(sta.pres[i] < sc.p_ur) {
	break;
      }
      if(sta.pres[i] > LCL) {
	//move up along a dry adiabat
	pr_this = sta.pres[i];
	t_this = (t_last+273.15)*
	  Math.pow(pr_this/pr_last,.286) - 273.15;
	sta.parcel_temp[i] = t_this + 273.15;
      } else {
	//move up along saturated adiabat
	if(!past_LCL) {
	  //move up to LCL on dry adabat, then further on saturated adiabat
	  pr_this = LCL;
	  t_this = (t_last+273.15) *
	    Math.pow(pr_this/pr_last,.286) - 273.15;
	  // get thetaE for this point
	  pte = sta.parcelThetaE(t_this+273.15,t_this+273.15,LCL);
	  //catch the next i level next time
	  i--;
	  past_LCL=true;
	  // indicate the LCL on the plot
	  sc.get_xy(pr_this,t_this,p2);
	  Color old = g.getColor();
	  g.setColor(Color.black);
	  draw_thick_line(g,3,p2.x-20,p2.y,
			  p2.x+20,p2.y);
	  g.setColor(old);
	} else {
	  pr_this = sta.pres[i];
	  t_this = sta.tempAlongSatAdiabat(pte,pr_this) - 273.15;
	  sta.parcel_temp[i] = t_this + 273.15;
	}
      }
      sc.get_xy(pr_this,t_this,p2);
      if(sc.is_on_plot(p2)) {
	draw_thick_line(g,3,p1.x,p1.y,p2.x,p2.y);
      }
      // keep separate memory locations
      p1.x = p2.x;
      p1.y = p2.y;
      pr_last = pr_this;
      t_last = t_this;
    }

    //calculate iCAPE and iCIn ("i" for interactive).
    //go down from top
    boolean in_CAPE=false;
    boolean in_CIN=false;
    boolean some_CAPE=false;
    // get LFC for this parcel
    double LFC = Sounding.MISSING;
    double delta_pr;
    Color CIn_color = new Color(0,255,0);
    Color CAPE_color = new Color(255,0,0);
    s.iCAPE=0;
    s.iCIn=0;
    for (int i=sta.n_levels-2;i>=0;i--) {
      if(sta.parcel_temp[i] == Sounding.MISSING) {
	continue;
      }
      delta_pr = sta.pres[i]-sta.pres[i+1];
      sc.get_xy(sta.pres[i],sta.temp[i]-273.15,p1);
      sc.get_xy(sta.pres[i],sta.parcel_temp[i]-273.15,p2);
      if(sta.parcel_temp[i] > sta.temp[i]) {
	if(sta.pres[i] < LCL) {
	  in_CAPE=true;
	  some_CAPE=true;
	  sta.CACIn_flag[i]=1;
	  s.iCAPE += 287.04*(sta.parcel_temp[i]-sta.temp[i])*
	    delta_pr/(sta.pres[i]-delta_pr/2);
	  g.setColor(CAPE_color);
	  draw_thick_line(g,1,p2.x,p2.y,p1.x,p1.y);
	} else {
	  if(some_CAPE &&
	     LFC > Sounding.MISSING - 1) {
	    LFC = LCL;
	  }
	  in_CAPE=false;
	}
      } else if(some_CAPE) {
	  if(LFC > Sounding.MISSING -1) {
	    LFC = sta.pres[i+1];
	  }
	in_CIN=true;
	sta.CACIn_flag[i]=-1;
	s.iCIn += 287.04*(sta.parcel_temp[i]-sta.temp[i])*
	            delta_pr/(sta.pres[i]-delta_pr/2);
	g.setColor(CIn_color);
	draw_thick_line(g,1,p2.x,p2.y,p1.x,p1.y);
      }
    }
    String var = "iCAPE "+
      MyUtil.goodRoundString(s.iCAPE,-1e10,1e10,"",0);
    MyUtil.drawCleanString(var,g,thermo_font,sc.x_upper-10,yp,
			   1,Color.black,Color.white,1);
    yp += y_inc;
    var = "iCIn "+
      MyUtil.goodRoundString(s.iCIn,-1e10,1e10,"",0);
    MyUtil.drawCleanString(var,g,thermo_font,sc.x_upper-10,yp,
			   1,Color.black,Color.white,1);
    yp += y_inc;
    var = "iLCL "+
      MyUtil.goodRoundString(LCL,-1e10,1e10,"",0);
    MyUtil.drawCleanString(var,g,thermo_font,sc.x_upper-10,yp,
			   1,Color.black,Color.white,1);
      
    yp += y_inc;
    if(LFC < Sounding.MISSING - 1) {
      var = "iLFC "+
	MyUtil.goodRoundString(LFC,-1e10,1e10,"",0);
      MyUtil.drawCleanString(var,g,thermo_font,sc.x_upper-10,yp,
			     1,Color.black,Color.white,1);
    }
  }
}
 
}  //end of class SkewTPlot
