; 
; This script computes the geopotential heights and compare them
;

close,1
openr,1,'RAOB_78486_db.rtf'
header = replicate(' ',4)
mark = fltarr(7,91)
readf,1,header
readf,1,mark
close,1
mark(1,*) /= 10.        ; Turn pressure into mb
mark(3,*) /= 10.        ; Turn temp into degC
mark(4,*) /= 10.        ; Turn dewp into degC

    ; Select the indices associated with good data
foom = where(mark(1,*) gt 0 and mark(2,*) lt 9900 and mark(3,*) lt 9900 and mark(4,*) lt 9900,nfoom)
    ; Compute the water vapor mixing ratio from the dewpoint field
mixr = replicate(0.,n_elements(foom))
mixr = dpt2w(mark(3,foom),mark(4,foom),mark(1,foom))
    ; Compute the new heights
feh = hypsometric2(mark(1,foom),mark(3,foom)+273.15,mixr,mark(2,foom(0))/1000.,mark_ht)
mark_ht *= 1000.
print,'Looking at the FSL data'
for i=0,10 < (nfoom-1) do print,format='(5x,3(F7.2,1x))',mark(2,foom(i)),mark_ht(i)

    ; Same logic, copied from above, but for another file
openr,1,'RAOB_78486_prepbufr.rtf'
header = replicate(' ',4)
prep = fltarr(10,124)
readf,1,header
readf,1,prep
close,1
prep(1,*) /= 10.        ; Turn pressure into mb
prep(3,*) /= 10.        ; Turn temp into degC
prep(4,*) /= 10.        ; Turn dewp into degC

foop = where(prep(1,*) gt 0 and prep(2,*) lt 9900 and prep(3,*) lt 9900 and prep(4,*) lt 9900,nfoop)
mixr = replicate(0.,n_elements(foop))
mixr = dpt2w(prep(3,foop),prep(4,foop),prep(1,foop))
feh = hypsometric2(prep(1,foop),prep(3,foop)+273.15,mixr,prep(2,foop(0))/1000.,prep_ht)
prep_ht *= 1000.
print,'Looking at the PrepBUFR data'
for i=0,10 < (nfoop-1) do print,format='(5x,3(F7.2,1x))',prep(2,foop(i)),prep_ht(i)

    ; Makes some plots
plot,mark(2,foom),mark(2,foom)-mark_ht,psym=8,color=0,yr=[-10,50],/yst, $
    chars=1.3,xtit='Height [m MSL]',ytit='Height Difference [m]',/nodata
oplot,mark(2,foom),mark(2,foom)-mark_ht,psym=7,thick=2,color=4
oplot,prep(2,foop),prep(2,foop)-prep_ht,psym=6,thick=2,color=2

xyouts,0.65,0.20,/nor,chars=1.2,color=0,'FSL-derived height'
xyouts,0.65,0.17,/nor,chars=1.2,color=0,'PrepBUFR-derived height'
plots,0.635,0.21,/nor,psym=7,thick=2,color=4
plots,0.635,0.18,/nor,psym=6,thick=2,color=2
end
