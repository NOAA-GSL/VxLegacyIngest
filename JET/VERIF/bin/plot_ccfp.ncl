; ===================================================================================
; plot_ccfp.ncl
; CCFP NCL plotting scripts
; Patrick Hofmann
; NOAA/OAR/ESRL/GSD/AMB
; 21 MAR 2011
;
; This script plots CCFP polygons on the NCWD grid.
;
; INPUT ARGUMENTS: INFILENAME OUTFILENAME
; Sample exec: ncl ../../scripts/plot_ccfp.ncl 'INFILENAME="ccfp+06.nc"' 'OUTFILENAME="test"'
; ===================================================================================

; Load additional NCL functions
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "/home/rtrr/VERIF/bin/cmap2.ncl"

; Set title for each plot here
VAR="CCFP"

; Change NetCDF lat/lon and vertical field names here
NLATNAME="latitude"
NLONNAME="longitude"
;VARNAME1="coverage"
;VARNAME2="confidence"
VARNAME="cov_conf"
FIELDNAME="model"
GRID="03km"

; Set fill areas and their associated colors
fill_areas = (/"Canada","Mexico","Land","Ocean","Water"/)
fill_colors = (/22,22,36,37,37/)

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
  res@mpFillOn                          = True
  res@mpFillAreaSpecifiers              = fill_areas
  res@mpSpecifiedFillColors             = fill_colors

  ; Resources for title text
  res@tiMainFont			= 22
  res@tiMainFontHeightF			= 0.01

  ; Resources for contours
  res@cnFillOn				= True
  res@cnLinesOn				= True
  res@cnLineLabelsOn			= False
  res@cnLineLabelInterval		= 1
  res@cnLineLabelFontHeightF            = 0.008
  res@cnLineLabelBackgroundColor 	= "Transparent"
  res@cnLevelSelectionMode		= "ExplicitLevels"
  res@cnLevels                          = (/ 10, 12, 20, 22, 30, 32/) ; Can't contour on exact interval values
  res@cnMonoFillPattern                 = False                       ; want multiple patterns 
  res@cnFillPatterns                    = (/ -1,0,0,3,3,17,17/)       ; the patterns
  res@cnMonoFillColor                   = False
  res@cnFillColors                      = (/ 0, 11, 2, 11, 2, 11, 2 /)
  res@cnMonoLineColor                   = False
  res@cnLineColors                      = (/ 11, 2, 11, 2, 11, 2 /)
  res@cnMonoLineThickness               = True
  res@cnLineThicknessF                  = 2.0
  res@cnMonoFillScale                   = False
  res@cnFillScales                      = (/ 1, 1, 1, .4, .4, .5, .5 /)

  res@cnInfoLabelOn			= False
  res@cnGridBoundPerimOn		= True

  ; Resources for label bar
  labres                                = True
  labres@lbLabelFont                    = 22
  labres@lbPerimOn                      = False
  labres@lbOrientation                  = "Vertical"
  labres@vpWidthF                       = 0.1
  labres@vpHeightF                      = 0.1
  labres@lbLabelFuncCode                = "~"  
  labres@lbBoxMajorExtentF              = 0.75
  labres@lbLabelFontHeightF             = 0.008
  labres@lbMonoFillPattern              = False       ; want multiple patterns 
  labres@lbMonoFillScale                = False
  labres@lbFillScales                   = (/ 1, .4, .5 /)

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
  
  ;res@cnFillMode = "RasterFill"

  ; Open output files and define color tables
  wks = gsn_open_wks(wkstype, OUTFILENAME)
  setvalues wks
  	"wkColorMap" : gen_colormap()
  end setvalues

  setvalues NhlGetWorkspaceObjectId()
    "wsMaximumSize" : 107108864
  end setvalues

  ; Load NetCDF file
  infile = addfile(INFILENAME,"r")

  ;cov  = infile->$VARNAME1$(:,:)   ;coverage
  ;conf = infile->$VARNAME2$(:,:)   ;confidence
  ccfp  = infile->$VARNAME$(:,:)    ;coverage and confidence (cov*10 + conf)

  ; Set up single field
  ;ccfp = cov*10 + conf

  ; Determine dimensions of the fields
  lats = infile->$NLATNAME$(:,:)
  lons = infile->$NLONNAME$(:,:)
  dims = dimsizes(lats)
  numx = dims(1)
  numy = dims(0)

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

  TITLE1 = "CCFP " + init_str1
  TITLE2 = GRID
  
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

  ; Create % coverage stats for Model/Obs figures
  if(FIELDNAME .eq. "obs" .or. FIELDNAME .eq. "model") then
	y     = where(ccfp .ge. 0.,1.,0)
	ytot  = sum(y)
	x1    = where(ccfp .le. 11. .and. ccfp .gt. 0.,1.,0)
	x1tot = sum(x1)
	x2    = where(ccfp .le. 13. .and. ccfp .gt. 0.,1.,0)
	x2tot = sum(x2)
	x3    = where(ccfp .le. 21. .and. ccfp .gt. 0.,1.,0)
	x3tot = sum(x3)
	x4    = where(ccfp .le. 23. .and. ccfp .gt. 0.,1.,0)
	x4tot = sum(x4)
	x5    = where(ccfp .le. 31. .and. ccfp .gt. 0.,1.,0)
	x5tot = sum(x5)
	x6    = where(ccfp .le. 33. .and. ccfp .gt. 0.,1.,0)
	x6tot = sum(x6)
  end if
  

  ;------------------------------------------------------------------------
  ; Set text and labelbar locations
  xtext = 0.13
  ytext = 0.17
  
  xlab = 0.39
  ylab = 0.22

  ; Plot field
  plot = gsn_contour_map(wks, ccfp, res)

  ; Get contour levels from plot
  getvalues plot@contour
	"cnLevels" : levels
  end getvalues

  ; Plot two separate labelbars
  do i=0,1
    if (i .eq. 0) then
	labels = (/ "High Conf"+"~C~Solid Cov","High Conf~C~Med Cov","High Conf~C~Sparse Cov" /)
	labres@lbFillPatterns                 = (/ 0,3,17 /)
        labres@lbFillColors                   = (/ 11,11,11 /) 
	labres@lbLabelPosition                = "Left"
    end if
    if (i .eq. 1) then
	labels = (/ "Low Conf~C~Solid Cov","Low Conf~C~Med Cov","Low Conf~C~Sparse Cov" /)
	labres@lbFillPatterns                 = (/ 0,3,17 /)
        labres@lbFillColors                   = (/ 2,2,2 /) 
	labres@lbLabelPosition                = "Right"
    end if

    lbid = gsn_create_labelbar_ndc(wks, 3, labels, xlab+i*.11, ylab, labres)
    draw(lbid)
  end do

  ; Plot area text
  gsn_text_ndc(wks, "Area >= HiConf/HiCov: "+sprintf("%6.4f",x1tot/ytot)+"~C~Area >= LoConf/HiCov: "+sprintf("%6.4f",x2tot/ytot)+"~C~Area >= HiConf/MedCov: "+sprintf("%6.4f",x3tot/ytot)+"~C~Area >= LoConf/MedCov: "+sprintf("%6.4f",x4tot/ytot)+"~C~Area >= HiConf/LoCov: "+sprintf("%6.4f",x5tot/ytot)+"~C~Area >= LoConf/LoCov: "+sprintf("%6.4f",x6tot/ytot), xtext, ytext, tres)

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
