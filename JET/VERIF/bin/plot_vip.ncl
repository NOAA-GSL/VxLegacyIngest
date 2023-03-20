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
; INPUT ARGUMENTS: INFILENAME MODEL FIELDNAME OUTFILENAME
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

VAR="VIP level VIL"

;
; Change NetCDF lat/lon and vertical field names here
;
NLATNAME="latitude"
NLONNAME="longitude"
VARNAME="vip"

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
  res@cnLevelSelectionMode		= "ExplicitLevels"
  res@cnLevels                         = (/ -998,0,1,2,3,4,5,6 /)
  res@cnFillColors                     = (/ 0,22,22,4,2,6,8,9,11 /)
  res@cnInfoLabelOn			= False
  res@cnGridBoundPerimOn		= True

  ; Resources for label bar
  labres                                = True
  labres@lbLabelFont                    = 22
  labres@lbPerimOn                      = False
  labres@lbOrientation                  = "Horizontal"

  if (FIELDNAME .eq. "verif") then
	labres@vpWidthF                 = 0.4
  else
	labres@vpWidthF                 = 0.5
  end if

  labres@vpHeightF                      = 0.06
  labres@lbLabelFontHeightF             = 0.012
  labres@lbMonoFillPattern              = True
  labres@lbFillColors                   = (/ 22,4,2,6,8,9,11 /)

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

  field = infile->$VARNAME$(:,:)   ;Model, Obs, or Verification

  ; Determine dimensions of the fields
  lats = infile->$NLATNAME$(:,:)
  lons = infile->$NLONNAME$(:,:)
  dims = dimsizes(lats)
  numx = dims(1)
  numy = dims(0)

  max_val = max(field)

  ; Set map projection information
  if(infile@MapProjection .eq. "LambertConformal") then
	res@mpLambertParallel1F             = infile@Standard_lat
	res@mpLambertParallel2F             = infile@Standard_lat
	res@mpLambertMeridianF              = infile@Standard_lon
	res@mpLeftCornerLatF                = infile@SW_corner_lat
	res@mpLeftCornerLonF                = infile@SW_corner_lon
	res@mpRightCornerLatF               = infile@NE_corner_lat
	res@mpRightCornerLonF               = infile@NE_corner_lon
	res@mpProjection                    = infile@MapProjection
  else
	res@mpLeftCornerLatF                = infile@SW_corner_lat
	res@mpLeftCornerLonF                = infile@SW_corner_lon
	res@mpRightCornerLatF               = infile@NE_corner_lat
	res@mpRightCornerLonF               = infile@NE_corner_lon
	res@mpProjection                    = infile@MapProjection
  end if

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

	
  if(FIELDNAME .eq. "model" .or. FIELDNAME .eq. "verif") then
	init_time1 = infile@InitialTime
	fcst_time = infile@ForecastTime

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

  end if

  if(FIELDNAME .eq. "verif") then
	trsh = infile@Threshold
  end if

  if(FIELDNAME .eq. "verif") then
	res@cnFillMode = "RasterFill"
  end if

  if(FIELDNAME .eq. "obs") then
	TITLE1 = MODEL
	TITLE2 = sprintf("%2.0f",ceil(infile@LatGridSpacing*100)) + "km"
  end if
  if(FIELDNAME .eq. "model") then
	TITLE1 = MODEL + " " + init_str1
	TITLE2 = sprintf("%2.0f",ceil(infile@LatGridSpacing*100)) + "km"
  end if
  if(FIELDNAME .eq. "verif") then
	TITLE1 = "NCWD vs " + MODEL + " " + init_str1 + " Categorical Scores"
	TITLE2 = "Threshold: " + sprintf("%2.0f",trsh) + "VIP level,  " + sprintf("%2.0f",ceil(infile@LatGridSpacing*100)) + "km"
  end if
  
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
  if(FIELDNAME .eq. "obs" .or. FIELDNAME .eq. "model") then
	y     = where(field .ge. 0.0,1.,0)
	ytot  = sum(y)
	x1    = where(field .ge. 1.0,1.,0)
	x1tot = sum(x1)
	x2    = where(field .ge. 2.0,1.,0)
	x2tot = sum(x2)
	x3    = where(field .ge. 3.0,1.,0)
	x3tot = sum(x3)
	x4    = where(field .ge. 4.0,1.,0)
	x4tot = sum(x4)
	x5    = where(field .ge. 5.0,1.,0)
	x5tot = sum(x5)
	x6    = where(field .ge. 6.0,1.,0)
	x6tot = sum(x6)
  end if
  if(FIELDNAME .eq. "verif") then
	a = where(field .eq. 4,1.,0)
	b = where(field .eq. 3,1.,0)
	c = where(field .eq. 2,1.,0)
	d = where(field .eq. 1,1.,0)
	
	hit  = sum(a)
	fa   = sum(b)
	miss = sum(c)
	cn   = sum(d)

	east  = where(lons .ge. 260,1.,0)
	
	ehit  = sum(a*east)
	efa   = sum(b*east)
	emiss = sum(c*east)
	ecn   = sum(d*east)

	west  = where(lons .lt. 260,1.,0)

	whit  = sum(a*west)
	wfa   = sum(b*west)
	wmiss = sum(c*west)
	wcn   = sum(d*west)

	if(hit+miss .eq. 0) then
		bias = 0.
		csi = 0.
		pod = 0.
		far = 0.
	else
		bias = (hit+fa)/ (hit+miss)
		csi = (hit) / (hit + miss + fa)
        	pod = (hit) / (hit + miss)
		far = (fa) / (hit + fa)
	end if
	cov = (hit + miss) / (hit + miss + fa + cn)

	if(ehit+emiss .eq. 0) then
		ebias = 0.
		ecsi = 0.
		epod = 0.
		efar = 0.
	else
		ebias = (ehit+efa)/ (ehit+emiss)
		ecsi = (ehit) / (ehit + emiss + efa)
        	epod = (ehit) / (ehit + emiss)
		efar = (efa) / (ehit + efa)
	end if
	ecov = (ehit + emiss) / (ehit + emiss + efa + ecn)

	if(whit+wmiss .eq. 0) then
		wbias = 0.
		wcsi = 0.
		wpod = 0.
		wfar = 0.
	else
		wbias = (whit+wfa)/ (whit+wmiss)
		wcsi = (whit) / (whit + wmiss + wfa)
        	wpod = (whit) / (whit + wmiss)
		wfar = (wfa) / (whit + wfa)
	end if
	wcov = (whit + wmiss) / (whit + wmiss + wfa + wcn)

  end if
	

  ;------------------------------------------------------------------------
  ; Plot field

  xtext = 0.12
  xlab = 0.25

  ytext = 0.22
  ylab = 0.27
  
  if(FIELDNAME .eq. "obs" .or. FIELDNAME .eq. "model") then
	;labres@lbLabelAlignment               = "InteriorEdges"
	
	plot = gsn_contour_map(wks, field, res)

	; Get contour levels from plot
  	getvalues plot@contour
  		"cnLevels" : levels
  	end getvalues
  
  	;labels   = sprintf("%2.0f",levels(1:))   ; Format the labels
	labels   = sprintf("%2.0f",(/0,1,2,3,4,5,6/))

  	gsn_labelbar_ndc(wks, dimsizes(levels)-1, labels, xlab, ylab, labres)

	gsn_text_ndc(wks, "Area >= 1 VIP Level: "+sprintf("%6.4f",x1tot/ytot)+"~C~Area >= 2 VIP Level: "+sprintf("%6.4f",x2tot/ytot)+"~C~Area >= 3 VIP Level: "+sprintf("%6.4f",x3tot/ytot)+"~C~Area >= 4 VIP Level: "+sprintf("%6.4f",x4tot/ytot)+"~C~Area >= 5 VIP Level: "+sprintf("%6.4f",x5tot/ytot)+"~C~Area >= 6 VIP Level: "+sprintf("%6.4f",x6tot/ytot), xtext, ytext, tres)
	gsn_text_ndc(wks,"Max Value (VIP Level)"+"~C~"+sprintf("%2.0f",max_val),xtext+.77,ylab-.02,tres)

  else
  	delete(res@cnFillColors)
  	delete(labres@lbFillColors)
  	delete(res@cnLevelSelectionMode)

  	res@cnLevelSelectionMode	= "ManualLevels"
  	res@cnMinLevelValF		= -0.5
  	res@cnMaxLevelValF		= 4.5
  	res@cnLevelSpacingF	        = 1
  	res@cnFillColors              = (/ 0,0,22,2,11,6 /)

  	labres@lbFillColors           = (/ 0,22,2,11,6 /)
  	csilabels                     = (/ "No Data","CR","Miss","FA","Hit" /)

	plot = gsn_contour_map(wks, field, res)
  	gsn_labelbar_ndc(wks, 5, csilabels, xlab, ylab, labres)

	gsn_text_ndc(wks,"CONUS"+"~C~Bias: "+sprintf("%6.4f",bias)+"~C~CSI:  "+sprintf("%6.4f",csi)+"~C~POD:  "+sprintf("%6.4f",pod)+"~C~FAR:  "+sprintf("%6.4f",far)+"~C~Obs Coverage: "+sprintf("%6.4f",cov), xtext, ytext, tres)
	gsn_text_ndc(wks,"WEST"+"~C~Bias: "+sprintf("%6.4f",wbias)+"~C~CSI:  "+sprintf("%6.4f",wcsi)+"~C~POD:  "+sprintf("%6.4f",wpod)+"~C~FAR:  "+sprintf("%6.4f",wfar)+"~C~Obs Coverage: "+sprintf("%6.4f",wcov), xtext+.63, ytext, tres)
	gsn_text_ndc(wks,"EAST"+"~C~Bias: "+sprintf("%6.4f",ebias)+"~C~CSI:  "+sprintf("%6.4f",ecsi)+"~C~POD:  "+sprintf("%6.4f",epod)+"~C~FAR:  "+sprintf("%6.4f",efar)+"~C~Obs Coverage: "+sprintf("%6.4f",ecov), xtext+.8, ytext, tres)
  end if

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
