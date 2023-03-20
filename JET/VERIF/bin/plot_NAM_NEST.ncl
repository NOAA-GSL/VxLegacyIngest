; ===================================================================================
; plot_verif.ncl
; WRF RR/HRRR NCL plotting scripts
; Patrick Hofmann
; NOAA/OAR/ESRL/GSD/AMB
; 03 June 2010
;
; This script plots radar reflectivity from observations and model, or
; the verification grid
;
; INPUT ARGUMENTS: INFILENAME  FIELDNAME OUTFILENAME
; ===================================================================================

; Load additional NCL functions
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "/home/rtrr/VERIF/bin/cmap_cref.ncl"
;
; Change title for each plot here
;

VAR="Composite Reflectivity (dBZ)"

;
; Change NetCDF lat/lon and vertical field names here
;
NLATNAME="latitude"
NLONNAME="longitude"
VARNAME="REFC_entireatmosphere(consideredasasinglelayer)"

begin

  ; Set plotting resources
  res					= True

  ; Resources for plot size
  res@gsnDraw				= False
  res@gsnFrame				= False
  res@gsnMaximize			= True
  res@gsnShape				= True
  res@tfDoNDCOverlay			= True
  
  ; Resources for map background
  res@mpDataBaseVersion			= "Ncarg4_1"
  res@mpDataSetName			= "Earth..4"
  res@mpOutlineBoundarySets             = "GeophysicalAndUSStates"
  res@mpDataResolution			= "FinestResolution"
  res@mpGridAndLimbOn			= False
  res@mpPerimOn				= True
  res@mpPerimLineThicknessF		= 2.0
  res@mpUSStateLineThicknessF		= 2.0
  res@mpNationalLineThicknessF		= 2.0
  res@mpGeophysicalLineThicknessF	= 2.0
  res@mpLimitMode			= "Corners"

  ; Resources for title text
  res@tiMainFont			= 22
  res@tiMainFontHeightF			= 0.01
  res@tiMainOn                          = False

  ; Resources for contours
  res@cnFillOn				= True
  res@cnLinesOn				= False
  res@cnLineLabelsOn			= False
  res@cnLineLabelInterval		= 1
  res@cnLineLabelFontHeightF            = 0.008
  res@cnLineLabelBackgroundColor 	= "Transparent"
  res@cnLevelSelectionMode		= "ExplicitLevels"
  ;res@cnMinLevelValF			= 0.0
  ;res@cnMaxLevelValF			= 75.0
  ;res@cnLevelSpacingF			= 5.0
  res@cnLevels                         = (/ -1,0,5,10,15,20,25,30,35,40,45,50,55,60,65,70,75 /)
  res@cnFillColors                     = (/ 0,22,22,4,3,2,20,6,7,8,21,9,11,19,18,15,14,22  /)
  res@cnInfoLabelOn			= False
  res@cnGridBoundPerimOn		= True

  ; Resources for label bar
  labres                                = True
  labres@lbLabelFont                    = 22
  labres@lbPerimOn                      = False
  labres@lbOrientation                  = "Horizontal"

  labres@vpWidthF                       = 0.6
  labres@vpHeightF                      = 0.06
  labres@lbLabelFontHeightF             = 0.012
  labres@lbMonoFillPattern              = True
  labres@lbFillColors                   = (/ 22,22,4,3,2,20,6,7,8,21,9,11,19,18,15,14,22  /)

  ; Resources for Statistic Text
  tres                                  = True
  tres@txFont                           = 22
  tres@txFontHeightF                    = 0.01
  tres@txFuncCode                       = "~"

  ; Resources for output filetype and resolution
  wkstype				= "png"
  wkstype@wkWidth			= 1280
  wkstype@wkHeight			= 960

  ; Resources for workstation colors
  wkstype@wkBackgroundColor		= "white"
  wkstype@wkForegroundColor		= "black"
  

  ; Open output files and define color tables
  wks = gsn_open_wks(wkstype, OUTFILENAME)
  setvalues wks
  	"wkColorMap" : gen_colormap()
  end setvalues

  setvalues NhlGetWorkspaceObjectId()
    "wsMaximumSize" : 67108864
  end setvalues

  ; Load NetCDF file
  infile = addfile(INFILENAME,"r")

  field = infile->$VARNAME$(0,:,:)   ;Model, Obs, or Verification

  ; Determine dimensions of the fields
  lats = infile->$NLATNAME$(:,:)
  lons = infile->$NLONNAME$(:,:)
  dims = dimsizes(lats)
  numx = dims(1)
  numy = dims(0)

  max_val = max(field)

  ; Set map projection information
  res@mpLambertParallel1F             = 25.0
  res@mpLambertParallel2F             = 25.0
  res@mpLambertMeridianF              = 265.0
  res@mpLeftCornerLatF                = 16.281
  res@mpLeftCornerLonF                = 233.8621
  res@mpRightCornerLatF               = 55.48137
  res@mpRightCornerLonF               = 302.6194
  res@mpProjection                    = "LambertConformal"

  valid_time = VALIDTIME

  year = stringtointeger(getSubString(valid_time,0,3))
  mon  = stringtointeger(getSubString(valid_time,4,5))
  day  = stringtointeger(getSubString(valid_time,6,7))
  hour = stringtointeger(getSubString(valid_time,8,9))

  time = (/0.0/)
  time@units = "seconds since 1970-01-01 00:00:0.0"
  date = ut_inv_calendar(year,mon,day,hour,0,0,time@units, 0)
  utc_date = ut_calendar(date, 0)

  year   = floattointeger(utc_date(:,0))    ; Convert to integer for
  month  = floattointeger(utc_date(:,1))    ; use in the sprinti function.
  day    = floattointeger(utc_date(:,2))
  hour   = floattointeger(utc_date(:,3))
  minute = floattointeger(utc_date(:,4))

  valid_str = "Valid " + sprinti("%0.2i/", month) + sprinti("%0.2i/",day) + \
	      sprinti("%0.4i", year) + " " + sprinti("%0.2i:00 ", hour) + "UTC"

	
  
  init_time1 = INITIALTIME
  fcst_time = FORECASTTIME

  delete(year)
  delete(mon)
  delete(day)
  delete(hour)
  delete(time)
  delete(date)

  year = stringtointeger(getSubString(init_time1,0,3))
  mon  = stringtointeger(getSubString(init_time1,4,5))
  day  = stringtointeger(getSubString(init_time1,6,7))
  hour = stringtointeger(getSubString(init_time1,8,9))

  time = (/0.0/)
  time@units = "seconds since 1970-01-01 00:00:0.0"
  date = ut_inv_calendar(year,mon,day,hour,0,0,time@units, 0)

  utc_date1 = ut_calendar(date, 0)
  year1   = floattointeger(utc_date1(:,0))    ; Convert to integer for
  month1  = floattointeger(utc_date1(:,1))    ; use in the sprinti function.
  day1    = floattointeger(utc_date1(:,2))
  hour1   = floattointeger(utc_date1(:,3))
  minute1 = floattointeger(utc_date1(:,4))

  init_str1 = " " + sprinti("%0.2i/",month1) + sprinti("%0.2i/",day1) + \
		sprinti("%0.4i",year1) + " " + sprinti("(%0.2i:00) ",hour1) + \
		sprinti("%0.2i",stringtointeger(fcst_time)) + " hr fcst"



  TITLE1 = MODEL + " " + init_str1
  TITLE2 = "5km"

  
  ; Create Main title text strings: 1 for valid time, 1 for obs/model, 1 for variable 
  
  txid1 = create "TextItems" textItemClass wks
  "txFuncCode" : "~"
  "txString" : TITLE1
  "txFont" : 22
  "txFontHeightF" : 0.015
  "txFontColor" : 1
  end create

  txid2 = create "TextItems" textItemClass wks
  "txFuncCode" : "~"
  "txString" : TITLE2
  "txFont" : 22
  "txFontHeightF" : 0.015
  "txFontColor" : 1
  end create

  txid3 = create "TextItems" textItemClass wks
  "txFuncCode" : "~"
  "txString" : valid_str
  "txFont" : 22
  "txFontHeightF" : 0.015
  "txFontColor" : 1
  end create

  txid4 = create "TextItems" textItemClass wks
  "txFuncCode" : "~"
  "txString" : VAR
  "txFont" : 22
  "txFontHeightF" : 0.015
  "txFontColor" : 1
  end create

  field@_FillValue = -999
  
  ; Create % coverage stats for Model/Obs figures
  y     = where(field .ge. 0.0,1.,0)
  ytot  = sum(y)
  x1    = where(field .ge. 15.0,1.,0)
  x1tot = sum(x1)
  x2    = where(field .ge. 20.0,1.,0)
  x2tot = sum(x2)
  x3    = where(field .ge. 25.0,1.,0)
  x3tot = sum(x3)
  x4    = where(field .ge. 30.0,1.,0)
  x4tot = sum(x4)
  x5    = where(field .ge. 35.0,1.,0)
  x5tot = sum(x5)
  x6    = where(field .ge. 40.0,1.,0)
  x6tot = sum(x6)
  x7    = where(field .ge. 45.0,1.,0)
  x7tot = sum(x7)
 
  ;------------------------------------------------------------------------
  ; Plot field

  ; Spacing is different for RR/RUC domain vs. HRRR domain
  xtext = 0.1
  xlab = 0.23

  ytext = 0.08
  ylab = 0.13
 
  res@cnFillMode          = "RasterFill"
  labres@lbLabelAlignment = "InteriorEdges"

    plot = gsn_contour_map(wks, field, res)

    ; Get contour levels from plot
    getvalues plot@contour
	    "cnLevels" : levels
    end getvalues

    labels   = sprintf("%2.0f",levels(1:))   ; Format the labels

    gsn_labelbar_ndc(wks, dimsizes(levels)-1, labels, xlab, ylab, labres)

    gsn_text_ndc(wks, "Area >= 15dBZ: "+sprintf("%6.4f",x1tot/ytot)+"~C~Area >= 20dBZ: "+sprintf("%6.4f",x2tot/ytot)+"~C~Area >= 25dBZ: "+sprintf("%6.4f",x3tot/ytot)+"~C~Area >= 30dBZ: "+sprintf("%6.4f",x4tot/ytot)+"~C~Area >= 35dBZ: "+sprintf("%6.4f",x5tot/ytot)+"~C~Area >= 40dBZ: "+sprintf("%6.4f",x6tot/ytot)+"~C~Area >= 45dBZ: "+sprintf("%6.4f",x7tot/ytot), xtext, ytext, tres)
    gsn_text_ndc(wks,"Max Value (dBZ)"+"~C~"+sprintf("%2.1f",max_val),xtext+.81,ylab-.02,tres)



  ianno1 = NhlAddAnnotation(plot,txid1)
  setvalues ianno1
    "amZone":           10
    "amSide":           "top"
    "amJust":           "bottomleft"
    "amParallelPosF":    0.0
    "amOrthogonalPosF":  0.05
  end setvalues

  ianno2 = NhlAddAnnotation(plot,txid2)
  setvalues ianno2
    "amZone":           10
    "amSide":           "top"
    "amJust":           "bottomleft"
    "amParallelPosF":    0.0
    "amOrthogonalPosF":  0.01
  end setvalues

  ianno3 = NhlAddAnnotation(plot,txid3)
  setvalues ianno3
    "amZone":           10
    "amSide":           "top"
    "amJust":           "bottomright"
    "amParallelPosF":    1.0
    "amOrthogonalPosF":  0.05
  end setvalues

  ianno4 = NhlAddAnnotation(plot,txid4)
  setvalues ianno4
    "amZone":           10
    "amSide":           "top"
    "amJust":           "bottomright"
    "amParallelPosF":    1.0
    "amOrthogonalPosF":  0.01
  end setvalues

  ; Draw and save
  draw(plot)	
  frame(wks)

  ;------------------------------------------------------------------------

end
