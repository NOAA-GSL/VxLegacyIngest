; $Id: dpt2w.pro,v 1.1 1997/12/15 16:12:42 d3h797 Release_ddt_1_13 $
;***********************************************************************************
;+
;Abstract:
; This function computes the water vapor mixing ratio given the temperature,
;	dewpoint, and pressure.  Note that computed mixing ratios that are
;	larger than the saturation mixing ratio will be set to -999.
;
;     Original matlab code from Dave Tobin, SSEC
;     Copied into IDL by Dave Turner
;     Copy Date:    December 1997
;
;     INPUTS:  temp = the ambient temperature, in degrees Celsius
;     	       dpt  = the dewpoint temperature, in degrees Celsius
;	       pres = the pressure, in mb
;
;     OUTPUT:  dpt2w = the mixing ratio, in g/kg
;
; Call:
	function dpt2w, temp, dpt, pres
;-
  tzero = 273.15
  eps = 0.621970585
  con = 6.1078
  cenkel = 273.15
  a = 17.2693882;
  b = 35.86;
 
  t = temp + tzero
  dp = dpt + tzero
  p = pres

  y = (cenkel - dp)/(b - dp)
  arg1 = exp(a*y)
  ww = (con*arg1*eps)/(p-con*arg1)
  w = ww*1000
  ws = wsat(temp, pres)

  foo = where(w gt ws, nhits)
  if(nhits gt 0) then w(foo) = -999.

  return, w
end


