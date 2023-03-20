; ===================================================================================
; plot_verif.ncl
; WRF RR/HRRR NCL plotting scripts
; Patrick Hofmann
; NOAA/OAR/ESRL/GSD/AMB
; 03 June 2010
;
; This script plots probabilities from observations and model, or
; the verification grid
;
; INPUT ARGUMENTS: INFILENAME MODEL FIELDNAME NCVAR TITLEVAR OUTFILENAME
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

;TITLEVAR="Convective Coverage"

;
; Change NetCDF lat/lon and vertical field names here
;
NLATNAME="latitude"
NLONNAME="longitude"
;NCVAR="coverage"

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
  
  if(FIELDNAME .eq. "verif") then
  	labres@vpWidthF                       = 0.3
  else
	labres@vpWidthF                       = 0.5
  end if
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

  ; Load NetCDF file
  infile = addfile(INFILENAME,"r")

  field = infile->$NCVAR$(:,:)   ;Model, Obs, or Verification

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
	TITLE2 = RES
  end if
  if(FIELDNAME .eq. "model") then
	TITLE1 = MODEL + " " + init_str1
	TITLE2 = RES
  end if
  if(FIELDNAME .eq. "verif") then
	TITLE1 = MODEL + " vs NSSL" + " " + init_str1 + " Categorical Scores"
	TITLE2 = "Threshold: " + sprintf("%2.0f",100*trsh) + "%,  " + RES
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
  "txString" : TITLEVAR
  "txFont" : 22
  "txFontHeightF" : 0.015
  "txFontColor" : 1
  end create

  field@_FillValue = -999
  ; Create % coverage stats for Model/Obs figures
  if(FIELDNAME .eq. "obs" .or. FIELDNAME .eq. "model") then
	y     = where(field .ge. 0.0,1.,0)
	ytot  = sum(y)
	x1    = where(field .ge. 25.0,1.,0)
	x1tot = sum(x1)
	x2    = where(field .ge. 40.0,1.,0)
	x2tot = sum(x2)
	x3    = where(field .ge. 75.0,1.,0)
	x3tot = sum(x3)
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

	ne  = where(lons .ge. 265 .and. lats .ge. 37.,1.,0)

	nhit  = sum(a*ne)
	nfa   = sum(b*ne)
	nmiss = sum(c*ne)
	ncn   = sum(d*ne)

	se  = where(lons .ge. 265 .and. lats .lt. 37.,1.,0)

	shit  = sum(a*se)
	sfa   = sum(b*se)
	smiss = sum(c*se)
	scn   = sum(d*se)

	if(ehit+emiss .eq. 0 .or. ehit+efa .eq. 0) then
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

	if(nhit+nmiss .eq. 0 .or. nhit+nfa .eq. 0) then
		nbias = 0.
		ncsi = 0.
		npod = 0.
		nfar = 0.
	else
		nbias = (nhit+nfa)/ (nhit+nmiss)
		ncsi = (nhit) / (nhit + nmiss + nfa)
        	npod = (nhit) / (nhit + nmiss)
		nfar = (nfa) / (nhit + nfa)
	end if
	ncov = (nhit + nmiss) / (nhit + nmiss + nfa + ncn)

	if(shit+smiss .eq. 0 .or. shit+sfa .eq. 0) then
		sbias = 0.
		scsi = 0.
		spod = 0.
		sfar = 0.
	else
		sbias = (shit+sfa)/ (shit+smiss)
		scsi = (shit) / (shit + smiss + sfa)
        	spod = (shit) / (shit + smiss)
		sfar = (sfa) / (shit + sfa)
	end if
	scov = (shit + smiss) / (shit + smiss + sfa + scn)

  end if
	

  ;------------------------------------------------------------------------
  ; Plot field

  if(FIELDNAME .eq. "verif") then
  	xtext = 0.1
  	xlab = 0.28
  	ytext = 0.17
	ylab = 0.27
  else
	xtext = 0.12
	xlab = 0.27
  	ytext = 0.24
  	ylab = 0.27
  end if
  
  if(FIELDNAME .eq. "obs" .or. FIELDNAME .eq. "model") then
	labres@lbLabelAlignment               = "InteriorEdges"
	
	plot = gsn_contour_map(wks, field, res)

	; Get contour levels from plot
  	getvalues plot@contour
  		"cnLevels" : levels
  	end getvalues
  
  	labels   = sprintf("%2.0f",levels(1:))   ; Format the labels

  	gsn_labelbar_ndc(wks, dimsizes(levels)-1, labels, xlab, ylab, labres)

	gsn_text_ndc(wks, "Area >= 25%: "+sprintf("%6.4f",x1tot/ytot)+"~C~Area >= 40%: "+sprintf("%6.4f",x2tot/ytot)+"~C~Area >= 75%: "+sprintf("%6.4f",x3tot/ytot), xtext, ytext, tres)
	gsn_text_ndc(wks,"Max Value (%)"+"~C~"+sprintf("%2.0f",max_val),xtext+.77,ytext,tres)

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

	gsn_text_ndc(wks,"East"+"~C~Bias: "+sprintf("%6.4f",ebias)+"~C~CSI:  "+sprintf("%6.4f",ecsi)+"~C~POD:  "+sprintf("%6.4f",epod)+"~C~FAR:  "+sprintf("%6.4f",efar)+"~C~Obs Coverage: "+sprintf("%6.4f",ecov), xtext, ytext, tres)
	gsn_text_ndc(wks,"NE"+"~C~Bias: "+sprintf("%6.4f",nbias)+"~C~CSI:  "+sprintf("%6.4f",ncsi)+"~C~POD:  "+sprintf("%6.4f",npod)+"~C~FAR:  "+sprintf("%6.4f",nfar)+"~C~Obs Coverage: "+sprintf("%6.4f",ncov), xtext+.63, ytext, tres)
	gsn_text_ndc(wks,"SE"+"~C~Bias: "+sprintf("%6.4f",sbias)+"~C~CSI:  "+sprintf("%6.4f",scsi)+"~C~POD:  "+sprintf("%6.4f",spod)+"~C~FAR:  "+sprintf("%6.4f",sfar)+"~C~Obs Coverage: "+sprintf("%6.4f",scov), xtext+.8, ytext, tres)
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
    "amOrthogonalPosF":  0.061
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
