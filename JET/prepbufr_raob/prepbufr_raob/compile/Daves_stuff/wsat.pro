; $Id: wsat.pro,v 1.1 1997/12/15 16:12:42 d3h797 Release_ddt_1_13 $
;***********************************************************************************
;+
;Abstract:
; This function computes the saturation water vapor mixing ratio given 
;	the temperature and pressure.  Note that for pressures less than
;	50 mb, wsat will be set to zero.
;
;     Original matlab code from Dave Tobin, SSEC
;     Copied into IDL by Dave Turner
;     Copy Date:    December 1997
;
;     INPUTS:  temp = the ambient temperature, in degrees Celsius
;	       pres = the pressure, in mb
;
;     OUTPUT:  wsat = the saturation mixing ratio, in g/kg
;
; Call:
    function wsat, temp, pres
;-
  eps = 0.621970585
 
  t = temp
  p = pres

  es = esat(t,0)
  es = es / 100.0	; Convert from Pa to hPa (mb)
  w = 1000.0 * eps * es / float(p-es)

  foo = where(p lt 50, nhits)
  if(nhits gt 0) then w(foo) = 0

  return, w
end



