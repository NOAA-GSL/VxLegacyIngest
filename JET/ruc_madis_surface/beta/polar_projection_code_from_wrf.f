// this code from http://www.mmm.ucar.edu/wrf/WG2/wrfbrowser/html_code/share/module_llxy.F.html

SUBROUTINE  set_ps (docs)  (proj) 1
      ! Initializes a polar-stereographic map projection from the partially
      ! filled proj structure. This routine computes the radius to the
      ! southwest corner and computes the i/j location of the pole for use
      ! in llij_ps and ijll_ps.
      IMPLICIT NONE
   
      ! Declare args
      TYPE(proj_info), INTENT(INOUT)    :: proj
  
      ! Local vars
      REAL                              :: ala1
      REAL                              :: alo1
      REAL                              :: reflon
      REAL                              :: scale_top
  
      ! Executable code
      reflon = proj%stdlon + 90.
  
      ! Compute numerator term of map scale factor
      scale_top = 1. + proj%hemi * SIN(proj%truelat1 * rad_per_deg)
  
      ! Compute radius to lower-left (SW) corner
      ala1 = proj%lat1 * rad_per_deg
      proj%rsw = proj%rebydx*COS(ala1)*scale_top/(1.+proj%hemi*SIN(ala1))
  
      ! Find the pole point
      alo1 = (proj%lon1 - reflon) * rad_per_deg
      proj%polei = proj%knowni - proj%rsw * COS(alo1)
      proj%polej = proj%knownj - proj%hemi * proj%rsw * SIN(alo1)

      RETURN

   END SUBROUTINE set_ps

SUBROUTINE  set_ps (docs)  (proj) 1
      ! Initializes a polar-stereographic map projection from the partially
      ! filled proj structure. This routine computes the radius to the
      ! southwest corner and computes the i/j location of the pole for use
      ! in llij_ps and ijll_ps.
      IMPLICIT NONE
   
      ! Declare args
      TYPE(proj_info), INTENT(INOUT)    :: proj
  
      ! Local vars
      REAL                              :: ala1
      REAL                              :: alo1
      REAL                              :: reflon
      REAL                              :: scale_top
  
      ! Executable code
      reflon = proj%stdlon + 90.
  
      ! Compute numerator term of map scale factor
      scale_top = 1. + proj%hemi * SIN(proj%truelat1 * rad_per_deg)
  
      ! Compute radius to lower-left (SW) corner
      ala1 = proj%lat1 * rad_per_deg
      proj%rsw = proj%rebydx*COS(ala1)*scale_top/(1.+proj%hemi*SIN(ala1))
  
      ! Find the pole point
      alo1 = (proj%lon1 - reflon) * rad_per_deg
      proj%polei = proj%knowni - proj%rsw * COS(alo1)
      proj%polej = proj%knownj - proj%hemi * proj%rsw * SIN(alo1)

      RETURN

   END SUBROUTINE set_ps


! Also versions for the wgs84 ellipsoid:
SUBROUTINE  set_ps_wgs84 (docs)  (proj) 1
      ! Initializes a polar-stereographic map projection (WGS84 ellipsoid) 
      ! from the partially filled proj structure. This routine computes the 
      ! radius to the southwest corner and computes the i/j location of the 
      ! pole for use in llij_ps and ijll_ps.

      IMPLICIT NONE
   
      ! Arguments
      TYPE(proj_info), INTENT(INOUT)    :: proj
  
      ! Local variables
      real :: h, mc, tc, t, rho

      h = proj%hemi

      mc = cos(h*proj%truelat1*rad_per_deg)/sqrt(1.0-(E_WGS84*sin(h*proj%truelat1*rad_per_deg))**2.0)
      tc = sqrt(((1.0-sin(h*proj%truelat1*rad_per_deg))/(1.0+sin(h*proj%truelat1*rad_per_deg)))* &
                (((1.0+E_WGS84*sin(h*proj%truelat1*rad_per_deg))/(1.0-E_WGS84*sin(h*proj%truelat1*rad_per_deg)))**E_WGS84 ))

      ! Find the i/j location of reference lat/lon with respect to the pole of the projection
      t = sqrt(((1.0-sin(h*proj%lat1*rad_per_deg))/(1.0+sin(h*proj%lat1*rad_per_deg)))* &
               (((1.0+E_WGS84*sin(h*proj%lat1*rad_per_deg))/(1.0-E_WGS84*sin(h*proj%lat1*rad_per_deg)) )**E_WGS84 ) )
      rho = h * (A_WGS84 / proj%dx) * mc * t / tc
      proj%polei = rho * sin((h*proj%lon1 - h*proj%stdlon)*rad_per_deg)
      proj%polej = -rho * cos((h*proj%lon1 - h*proj%stdlon)*rad_per_deg)

      RETURN

   END SUBROUTINE set_ps_wgs84

SUBROUTINE  llij_ps_wgs84 (docs)  (lat,lon,proj,i,j) 1
      ! Given latitude (-90 to 90), longitude (-180 to 180), and the
      ! standard polar-stereographic projection information via the 
      ! public proj structure, this routine returns the i/j indices which
      ! if within the domain range from 1->nx and 1->ny, respectively.
  
      IMPLICIT NONE
  
      ! Arguments
      REAL, INTENT(IN)               :: lat
      REAL, INTENT(IN)               :: lon
      REAL, INTENT(OUT)              :: i !(x-index)
      REAL, INTENT(OUT)              :: j !(y-index)
      TYPE(proj_info),INTENT(IN)     :: proj
  
      ! Local variables
      real :: h, mc, tc, t, rho

      h = proj%hemi

      mc = cos(h*proj%truelat1*rad_per_deg)/sqrt(1.0-(E_WGS84*sin(h*proj%truelat1*rad_per_deg))**2.0)
      tc = sqrt(((1.0-sin(h*proj%truelat1*rad_per_deg))/(1.0+sin(h*proj%truelat1*rad_per_deg)))* &
                (((1.0+E_WGS84*sin(h*proj%truelat1*rad_per_deg))/(1.0-E_WGS84*sin(h*proj%truelat1*rad_per_deg)))**E_WGS84 ))

      t = sqrt(((1.0-sin(h*lat*rad_per_deg))/(1.0+sin(h*lat*rad_per_deg))) * &
               (((1.0+E_WGS84*sin(h*lat*rad_per_deg))/(1.0-E_WGS84*sin(h*lat*rad_per_deg)))**E_WGS84))

      ! Find the x/y location of the requested lat/lon with respect to the pole of the projection
      rho = (A_WGS84 / proj%dx) * mc * t / tc
      i = h *  rho * sin((h*lon - h*proj%stdlon)*rad_per_deg)
      j = h *(-rho)* cos((h*lon - h*proj%stdlon)*rad_per_deg)

      ! Get i/j relative to reference i/j
      i = proj%knowni + (i - proj%polei)
      j = proj%knownj + (j - proj%polej)
  
      RETURN

   END SUBROUTINE llij_ps_wgs84

