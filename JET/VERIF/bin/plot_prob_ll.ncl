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
; INPUT ARGUMENTS: INFILENAME OUTFILENAME VARNAME TITLE
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
;VARNAME="WAF"
;TITLE="Enroute Weather Avoidance Field, 29 Kft"
VAR="Probability (%)"

; Load NetCDF file
infile = addfile(INFILENAME,"r")

field = infile->$VARNAME$(:,:)  

;
; Change NetCDF lat/lon and vertical field names here
;
NLATNAME="latitude"
NLONNAME="longitude"

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

  ; Resources for contours
  res@cnFillOn				= True
  res@cnLinesOn				= False
  res@cnLineLabelsOn			= False
  res@cnLineLabelInterval		= 1
  res@cnLineLabelFontHeightF            = 0.008
  res@cnLineLabelBackgroundColor 	= "Transparent"
  res@cnLevelSelectionMode		= "ManualLevels"
  res@cnMissingValFillPattern           = 0
  res@cnMissingValFillColor             = 0
  res@cnMinLevelValF			= 0-.1
  res@cnMaxLevelValF			= 100.0-.1
  res@cnLevelSpacingF			= 10.0
  ;res@cnLevels                         = (/ -1,0,.4,10,20,30,40,50,60,70,80,90,100 /)
  res@cnFillColors                     = (/ 22,22,4,3,2,20,6,7,8,9,11,10/)
  res@cnInfoLabelOn			= False
  res@cnGridBoundPerimOn		= True

  ; Resources for label bar
  labres                                = True
  labres@lbLabelFont                    = 22
  labres@lbPerimOn                      = False
  labres@lbOrientation                  = "Horizontal"
  labres@vpWidthF                       = 0.5
  labres@vpHeightF                      = 0.06
  labres@lbLabelFontHeightF             = 0.012
  labres@lbMonoFillPattern              = True
  labres@lbFillColors                   = (/22,4,3,2,20,6,7,8,9,11,10/)

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

  res@mpLeftCornerLatF                = infile@SWCornerLat
  res@mpLeftCornerLonF                = infile@SWCornerLon
  res@mpRightCornerLatF               = infile@NECornerLat
  res@mpRightCornerLonF               = infile@NECornerLon
  res@mpProjection                    = infile@MapProjection

  valid_time = infile@ValidTime

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
  
  
  init_time = infile@InitialTime
  fcst_time = infile@ForecastHr

  delete(year)
  delete(mon)
  delete(day)
  delete(hour)
  delete(time)
  delete(date)

  year = stringtointeger(getSubString(init_time,0,3))
  mon  = stringtointeger(getSubString(init_time,4,5))
  day  = stringtointeger(getSubString(init_time,6,7))
  hour = stringtointeger(getSubString(init_time,8,9))

  time = (/0.0/)
  time@units = "seconds since 1970-01-01 00:00:0.0"
  date = ut_inv_calendar(year,mon,day,hour,0,0,time@units, 0)

  utc_date1 = ut_calendar(date, 0)
  year1   = floattointeger(utc_date1(:,0))    ; Convert to integer for
  month1  = floattointeger(utc_date1(:,1))    ; use in the sprinti function.
  day1    = floattointeger(utc_date1(:,2))
  hour1   = floattointeger(utc_date1(:,3))
  minute1 = floattointeger(utc_date1(:,4))

  init_str = sprinti("%0.2i/",month1) + sprinti("%0.2i/",day1) + \
	     sprinti("%0.4i",year1) + " " + sprinti("(%0.2i:00) ",hour1) + \
	     sprinti("%0.2i",stringtointeger(fcst_time)) + " hr fcst"

  ; Create Main title text strings: 1 for valid time, 1 for obs/model, 1 for variable 
  
  txid1 = create "TextItems" textItemClass wks
  "txFuncCode" : "~"
  "txString" : TITLE
  "txFont" : 22
  "txFontHeightF" : 0.015
  "txFontColor" : 1
  end create

  txid2 = create "TextItems" textItemClass wks
  "txFuncCode" : "~"
  "txString" : init_str
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
  "txFontHeightF" : 0.018
  "txFontColor" : 1
  end create

  field@_FillValue = -999
  
  ;------------------------------------------------------------------------
  ; Plot field

  xlab = 0.25
  ylab = 0.27
  
  labres@lbLabelAlignment               = "InteriorEdges"
	
  plot = gsn_contour_map(wks, field, res)

  ; Get contour levels from plot
  getvalues plot@contour
  	"cnLevels" : levels
  end getvalues
  
  labels   = sprintf("%2.0f",levels(1:))   ; Format the labels

  gsn_labelbar_ndc(wks, dimsizes(levels), labels, xlab, ylab, labres)

  ianno1 = NhlAddAnnotation(plot,txid1)
  setvalues ianno1
    "amZone":           10
    "amSide":           "top"
    "amJust":           "bottomleft"
    "amParallelPosF":    0.0
    "amOrthogonalPosF":  0.07
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
    "amOrthogonalPosF":  0.07
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
