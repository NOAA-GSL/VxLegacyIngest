import math

PI = 3.14159265
piby2 = PI/2.
radpd = PI/180.0
deg_to_radians = 0.0174533
rerth = 6.3712e+6
nan = float('nan')

class Projection:

  def __init__(self,_projection,_alat1,_elon1,_elonv,_alattan,_dx,_nx,_ny):
    # global ala,an,cosltn,elonv,elonvr,h,nx,ny,polei,polej,radpd,rebydx,rm
    global PI,piby2,radpd,deg_to_radians,rerth,nan

    if "lambert" not in _projection.lower():
        print "ERROR from class Projection: projection is not lambert. projection is",grid_type
        sys.exit()

    self.projection = _projection
    self.alat1=_alat1
    self.elon1=_elon1
    self.elonv=_elonv
    self.alattan=_alattan
    self.dx=_dx
    self.nx=_nx
    self.ny=_ny

    if self.alattan > 0:
        self.h = 1.
    else:
        self.h = -1.
  
    degprd = 1./radpd
    self.rebydx = rerth/self.dx
    self.alatn1 = self.alattan * radpd
    self.an = self.h * math.sin(self.alatn1)
    self.cosltn = math.cos(self.alatn1)
    elon1L = self.elon1
    if(self.elon1 - self.elonv) > 180.:
        elon1L = self.elon1 - 360.
    if(self.elon1 - self.elonv) < (-180.):
        elon1L = self.elon1 + 360.
    self.elonvr = self.elonv * radpd
    ala1 =  self.alat1 * radpd
    rmLL = self.rebydx * math.pow(self.cosltn,(1.-self.an))*math.pow((1.+self.an),self.an) * \
           math.pow(math.cos(ala1)/(1.+self.h*math.sin(ala1)),self.an)/self.an
    elo1 = elon1L * radpd
    arg = self.an * (elo1-self.elonvr)
    self.polei = 1. - self.h * rmLL * math.sin(arg)
    self.polej = 1. + rmLL * math.cos(arg)
    # the vars below *may* be needed for ij2latlon
    #theta = PI*(1.-self.an)
    #aninv = 1./self.an
    #aninv2 = aninv/2.
    self.set = True
    self.count = 0

  def __str__(self):
    return "%s,%s,%s.%s,%s,%s,%s,%s" % \
    (self.projection,self.alat1,self.elon1,self.elonv,self.alattan,self.dx,self.nx,self.ny)
    
  def latlon2ij(self,alat,elon):
    global PI,piby2,radpd,deg_to_radians,rerth,nan
    if not self.set:
        print "ERROR. Projection not initialized!"
        sys.exit()

    ala =  alat * radpd
    rm = self.rebydx * math.pow(self.cosltn,(1.-self.an)) * math.pow((1.+self.an),self.an) * \
         math.pow(math.cos(ala)/(1.+self.h*math.sin(ala)),self.an)/self.an

    elonL = elon
    if(elon  - self.elonv) > 180.:
        elonL  = elon  - 360.
    if(elon - self.elonv) < (-180.):
        elonL = elon + 360.
    elo = elonL * radpd
    arg = self.an*(elo-self.elonvr)
    xi_out = self.polei + self.h * rm * math.sin(arg)
    yj_out = self.polej - rm * math.cos(arg)

    # reference to (0,0) for C and python, instead of (1,1) for fortran */
    xi_out -= 1
    yj_out -= 1
    if xi_out < 0 or xi_out >= self.nx-0.5 or yj_out < 0 or yj_out >= self.ny-0.5:
        xi_out = nan
        yj_out = nan
    else:
        self.count +=1
        if self.count < 0:
           print alat,elon,xi_out,yj_out,rm,arg,self.polei,self.polej

    return [xi_out,yj_out]

# module for w3fb-related methods
# ADAPTED by WRM from...
#   subprogram  documentation  block
#
# subprogram:  w3fb12        lambert(i,j) to lat/lon for grib
#   prgmmr: stackpole        org: nmc42       date:88-11-28
#
# abstract: converts the coordinates of a location on earth given in a
#   grid coordinate system overlaid on a lambert conformal tangent
#   cone projection true at a given n or s latitude to the
#   natural coordinate system of latitude/longitude
#   w3fb12 is the reverse of w3fb11.
#   uses grib specification of the location of the grid
#
# program history log:
#   88-11-25  original author:  stackpole, w/nmc42
# 2001-07-10  converted to java by w.r.moninger r/fs1 (wrm)
#
# usage:  call w3fb12(xi,xj,alat1,elon1,dx,elonv,alatan,alat,elon,ierr,
#                                   ierr)
#   input argument list:
#     alat1    - latitude  of lower left point of grid (point 1,1)
#                latitude <0 for southern hemisphere; real*4
#     elon1    - longitude of lower left point of grid (point 1,1)
#                  east longitude used throughout; real*4
#     dx       - mesh length of grid in meters at tangent latitude
#     elonv    - the orientation of the grid.  i.e.,
#                the east longitude value of the vertical meridian
#                which is parallel to the y-axis (or columns of
#                the grid) along which latitude increases as
#                the y-coordinate increases.  real*4
#                this is also the meridian (on the other side of the
#                tangent cone) along which the cut is made to lay
#                the cone flat.
#     alattan   - the latitude at which the lambert cone is tangent to
#                (touches or osculates) the spherical earth.
#                 set negative to indicate a
#                 southern hemisphere projection; real*4
#
#   remarks: formulae and notation loosely based on hoke, hayes,
#     and renninger's "map projections and grid systems...", march 1981
#     afgwc/tn-79/003


# end of w3fb11    
