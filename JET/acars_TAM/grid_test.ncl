; run this by using 'ncl grid_test.ncl'
; $NCARG_ROOT should be /apps/ncl/6.3.0 for the latest (as of Feb 17) version
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
;
; use a current file below
grb_file = addfile("/lfs4/BMC/nrtrr/NCO_dirs/stmp/tmpnwprd/RRFS_NA_13km_dev1/2021051000/postprd/RRFS_NA_13km.t00z.bgrd3df000.tm00.grib2","r")
;
lat = grb_file->gridlat_0(:,:)
lon = grb_file->gridlon_0(:,:)
;
; Get the closest grid point for the lat/lon point
;
RLAT=53.9
RLON= -122.8
gridpts1 = wrf_latlon_to_ij(lat, lon, RLAT, RLON)
i1 = gridpts1(0)
j1 = gridpts1(1)
print("i1 = "+i1)
print("j1 = "+j1)
