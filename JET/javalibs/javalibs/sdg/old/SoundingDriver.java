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

import java.net.*;
import java.awt.*;

public interface SoundingDriver {

  static final double default_p_lr = 1050.0; // pressure lower right
  static final double default_p_ur = 150.0;  // pressure upper right
  static final double default_t_ll = -40.0;  // temp lower left
  static final double default_t_lr = 50.0;   // temp lower right
  // get potential temperatures consistent with the above
  static final double default_theta_ll = -43.230778;  //theta lower left
  static final double default_theta_lr = 45.522083;   // theta lower right
  
// should provide the name of the log file, or null if none
public String get_log_file();
  
// should provide the code_base
public URL get_code_base();

/** returns true if the SoundingPanel is to load a sounding when
    it is first instantiated
*/
public boolean get_initial_load();

/** returns startSecs (only needed if initial_load is true)
 */
public int get_startSecs();

/** returns endSecs (only needed if initial_load is true)
 */
public int get_endSecs();

/** returns latest (only needed if initial_load is true)
 */
public boolean get_latest();

/** returns desired airport (only needed if initial_load is true)
 */
public String get_desired_airport();

/** returns data_source for sounding (only needed if initial_load is true)
 */
public String get_data_source();
 
public String get_load_btn_title();

public Dimension get_plot_size();

public void set_showing_soundingsFrame(boolean visible);

public void set_soundingsFrame_btn(String s);

/**
 * data_sources is provides a string in the form
 * "source1_title,source1_id,source2_title,source2_id..."
 * where the titles are the button titles that should appear
 * in the LoadSoundingsFrame, and the id's are the id's that should be
 * sent to SoundingLoader as the "data_source"
 */
public String get_data_sources();
 
}
