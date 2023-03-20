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
 * plots wind barbs
 */
public final class Barb {
  static float MISSING = 99999.f;

  /**
   * default is to plot appropriate to the Northern Hemisphere
   */
public static void plot(Graphics g, int x, int y, float wind_dir,
			float wind_speed, int scale, int pt_size,
			Color c) {
  plot(g,x,y,wind_dir,wind_speed,scale,pt_size,c,1);
}
  
  /**
   * if lat is input, we plot barbs for either hemisphere.
   * lat is only used to ensure barbs are on the correct side of
   * the stem in the southern hemisphere
   */
public static void plot(Graphics g, int x, int y, float wind_dir,
			float wind_speed, int scale, int pt_size,
			Color c, float lat) {
        double wsp25,slant,barb,d,c195,s195;
    double x0,y0;
    int x1,y1,x2,y2,x3,y3,nbarb50,nbarb10,nbarb5;

    if(scale == 0) {
      return;
    }
    g.setColor(c);
    // sanity check
    if(wind_dir < 0 || wind_dir > 360) {
      Debug.println("bad wind_dir: "+wind_dir);
    } else {
    // put directions in 0-359.9 degree range
    while(wind_dir < 0) {wind_dir += 360;}
    while(wind_dir >= 360) {wind_dir -= 360;}
    //determine the initial (minimum) length of the flag pole
    if(wind_speed >= 2.5 &&
       wind_speed < 400.) {

        wsp25 = Math.max(wind_speed+2.5,5.);
        slant = 0.15*scale;
        barb = 0.4*scale;
        x0 = Math.sin(wind_dir/57.3);
        y0 = -Math.cos(wind_dir/57.3);

        //plot the flag pole
        d = barb;
	if(lat < 0) {
	  barb = - barb;
	}
        x1 = (int)(x +x0*d);
        y1 = (int)(y +y0*d);

        //determine number of wind barbs needed for 10 and 50 kt winds
        nbarb50 = (int)(wsp25/50.f);
        nbarb10 = (int)((wsp25 - (nbarb50 * 50.f))/10.f);
        nbarb5 =  (int)((wsp25 - (nbarb50 * 50.f) - (nbarb10 * 10.f))/5.f);

       //2.5 to 7.5 kt winds are plotted with the barb part way done the pole
       if(nbarb5 == 1) {
        barb = barb*.4;
        double shortslant = slant*.4;
        x1 = (int)(x + x0*d);
        y1 = (int)(y + y0 *d);

        x2 = (int)(x + x0*(d+shortslant) - y0*barb);
        y2 = (int)(y + y0*(d+shortslant) + x0*barb);

        g.drawLine(x1,y1,x2,y2);
       }
       //add a little more pole
       if(wsp25 >= 5. && wsp25 < 10.) {
        d = d+.125*scale;
        x1=(int)(x+x0*d);
        y1=(int)(y+y0*d);
        g.drawLine(x,y,x1,y1);
       }

       //now plot any 10 kt wind barbs
       barb=0.4*scale;
       if(lat < 0) {
	 barb = -barb;
       }
       for(int j=0;j<nbarb10;j++) {
        d = d +0.125*scale;
        x1=(int)(x + x0*d);
        y1=(int)(y + y0*d);
        x2 = (int)(x + x0*(d+slant) - y0*barb);
        y2 = (int)(y + y0*(d+slant) + x0*barb);

        g.drawLine(x1,y1,x2,y2);
       }

       g.drawLine(x,y,x1,y1);

       //lengthn the pole to accomodate the 50 not barbs
       if(nbarb50 > 0) {
        d = d +0.125*scale;
        x1=(int)(x + x0*d);
        y1=(int)(y + y0*d);
        g.drawLine(x,y,x1,y1);
       }

       //plot the 50 kt wind barbs
       s195 = Math.sin(195/57.3);
       c195 = Math.cos(195/57.3);
       barb=0.4*scale;
       if(lat < 0) {
	 c195 = -c195;
       }
       for(int j=0;j<nbarb50;j++) {
        x1=(int)(x + x0*d);
        y1=(int)(y + y0*d);
        d = d+0.3*scale;
        x3=(int)(x+x0*d);
        y3=(int)(y+y0*d);
        x2=(int)(x3+barb*(x0*s195+y0*c195));
        y2=(int)(y3-barb*(x0*c195-y0*s195));
        int[] xp = {x1,x2,x3};
        int[] yp = {y1,y2,y3};
        g.fillPolygon(xp,yp,3);
        //start location for the next barb
        x1=x3;
        y1=y3;
       }
    } else if(wind_speed < 2.5){
      // wind < 2.5 mph.  Plot a circle
      int rad = (int)(0.7*pt_size);
      g.setColor(c);
      g.drawOval(x-rad,y-rad,2*rad,2*rad);
    } else if(wind_speed != MISSING){
      Debug.println("BAD WIND SPEED: "+wind_speed);
    }
    } // end good wind direction
}
}
