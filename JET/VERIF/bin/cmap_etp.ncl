;
; colormap for echo top, VIL, and RVIL
;
function gen_colormap( )
begin
        ;This procedure explicitly sets the red, green, and blue
        ;intensities for each element in a colormap array.
        ;
        return( (/ (/1.000,1.000,1.000/), \   ; 0 (background)
                (/0.000,0.000,0.000/), \   ; 1 (foreground)
                (/.443,.294,.545/), \      ; 2 lavender
                (/.471,.471,.471/), \      ; 3 medium grey
                (/.627,.627,.627/), \      ; 4 light grey
                (/.000,.596,.000/), \      ; 5 green
                (/.000,.800,.000/), \      ; 6 light green
                (/.000,.098,.800/), \      ; 7 blue
                (/.000,.722,.800/), \      ; 8 light blue
                (/.722,.400,.000/), \      ; 9 brown
                (/.800,.502,.098/), \      ; 10 light brown
                (/.624,.624,.000/), \      ; 11 dark yellow
                (/.800,.800,.000/), \      ; 12 yellow
                (/.659,.000,.000/), \      ; 13 dark red
                (/.800,.000,.000/), \      ; 14 red
                (/.720,.000,.720/), \      ; 15 purple
                (/.800,.800,.800/), \      ; 16 very light grey
		(/.200,.200,.200/), \      ; 17 missing value color (dark grey)
		(/0.00,0.00,1.00/), \      ; 18 contingency table blue
         	(/0.00,1.00,0.00/), \      ; 19 contingency table green
         	(/1.00,0.00,0.00/), \      ; 20 contingency table red
         	(/0.66,0.66,0.66/) /) )    ; 21 contingency table grey

end

