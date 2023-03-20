; $Id: esat.pro,v 1.9 2016/04/27 14:32:35 Dave.Turner Exp $
;***********************************************************************************
;+
;Abstract:
;   This function computes the saturation vapor pressure over liquid water or ice
;     Original fortran code written by Jim Liljegren
;     Copied into IDL by Dave Turner
;     Copy Date:    September 28, 1995
;
;     INPUTS:  temp = temperature at which the saturation pressure is desired;
;				in degrees Celsius
;	       ice  = toggle to select over liquid (0) or ice (1)
;				below -10 degrees Celsius
;
;     OUTPUT:  esat = the saturation vapor pressure; in Pascals (Pa)
;				1 millibar = 100 Pa = 0.1 kPa
; Call:
	function esat, temp, ice
;-

  es0 = 611.0
  gascon = 461.5
  trplpt = 273.16
  tzero = 273.15

	; Compute saturation vapor pressure (es, in mb) over water or ice at
	; temperature temp (in Kelvin) using te Goff-Gratch formulation (List, 1963)

  tk = temp + tzero
  es = replicate(0.0, n_elements(temp))

  IF (ice eq 0) then begin
    wdx = lindgen(n_elements(temp))
    nw = n_elements(temp)
    nice = 0
  endif else begin
    icedx = where(tk LE 273.16, nice)
    wdx = where(tk GT 267.16, nw)
  endelse

  IF (nw GT 0) THEN BEGIN
    y = 373.16/tk(wdx)
    es(wdx) = double (-7.90298 * (y - 1.0) + 5.02808 * ALOG10(y) - $
  	1.3816e-7 * (10 ^ (11.344 * (1.0 - (1.0 / y))) - 1.0) + $
	8.1328e-3 * (10 ^ (-3.49149 * (y - 1.0)) - 1.0) + ALOG10(1013.246))
  ENDIF

  IF (nice GT 0 ) THEN BEGIN
    ;; for ice
    y = 273.16 / tk(icedx)
    es(icedx) = double(-9.09718 * (y - 1.0) - 3.56654 * ALOG10(y) + $
                   0.876793 * (1.0 - (1.0 / y)) + ALOG10(6.1071))
  ENDIF 
  
  es = 10.0 ^ es

  ;; convert from millibar (mb) to Pa
  es = es * 100
  return, es
end



