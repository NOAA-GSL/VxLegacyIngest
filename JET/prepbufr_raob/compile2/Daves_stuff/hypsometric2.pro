; $Id: hypsometric2.pro,v 1.1 2002/01/16 13:28:15 dturner Release_ddt_1_13 $
;   (See below for Paul's RCS Id)
;+
; NAME:
;       geopotential_altitude	- Paul van Delst's name of the routine
;			(I renamed it to this).
;
; PURPOSE:
;       This function calculates geopotential altitudes using the hypsometric equation.
;    It is like the "hypsometric" function I have implemented, but this one
;    also accounts for water vapor in the atmosphere.
;
; CATEGORY:
;       Meteorology
;
; CALLING SEQUENCE:
;       result = hypsometric2( pressure, $          ; Input
;                              temperature, $       ; Input
;                              mixing_ratio, $      ; Input
;                              surface_altitude, $  ; Input
;                              altitude )           ; Output
;
; INPUTS:
;       pressure:        Array of pressure in mb
;       temperature:     Array of temperature in K
;       mixing_ratio:    Array of water vapor mixing ratio in g/kg
;       surface_height:  Height of surface in km. 
;
; KEYWORD PARAMETERS:
;       None.
;
; OUTPUTS:
;       altitude:        Geopotential altitudes in km in the same order as the
;                          input data.
;
;       Function returns a flag:
;         result = -1 Error occurred during calculation
;                =  1 Everything worked fine 
;
; CALLS:
;       None.
;
; COMMON BLOCKS:
;       None
;
; SIDE EFFECTS:
;       None
;
; RESTRICTIONS:
;       - Input pressure, temperature and mixing_ratio MUST be arrays with at
;         LEAST two elements where the element with the highest pressure corresponds
;         to the surface altitude passed.
;       - Input surface height must be > or = to 0.0km and a SCALAR.
;       - No allowance is made, yet, for the change in the acceleration due to 
;         gravity with altitude.
;
; PROCEDURE:
;       Geopotential heights are calculated using the hypsometric equation:
;
;                         -
;                    Rd * Tv    [  p1  ]
;         z2 - z1 = --------- ln[ ---- ]
;                       g       [  p2  ]
;
;       where Rd    = gas constant for dry air (286.9968933 J/K/kg),
;             g     = acceleration due to gravity (9.80616m/s^2),
;             Tv    = mean virtual temperature for an atmospheric layer,
;             p1,p2 = layer boundary pressures, and
;             z1,z2 = layer boundary heights.
;
;       The virtual temperature, the temperature that dry air must have in
;       order to have the same density as moist air at the same pressure, is
;       calculated using:
;
;                  [      1 - eps      ]
;         Tv = T * [ 1 + --------- * w ]
;                  [        eps        ]
;
;       where T   = temperature,
;             w   = water vapor mixing ratio, and
;             eps = ratio of the molecular weights of water and dry air (0.621970585).
;
; EXAMPLE:
;       Given arrays of pressure, temperature, and mixing ratio:
;
;         IDL> PRINT, p, t, mr
;               1015.42      958.240
;               297.180      291.060
;               7.83735      5.71762
;
;       the geopotential altitudes can be found by typing:
;
;         IDL> result = geopotential_altitude( p, t, mr, 0.0, alt )
;         IDL> PRINT, result, alt
;                1      0.00000     0.500970
;
; MODIFICATION HISTORY:
; 	Written by:     Paul van Delst, CIMSS/SSEC, 08-Dec-1997
;
; $Log: hypsometric2.pro,v $
; Revision 1.1  2002/01/16 13:28:15  dturner
; Initial revision
;
; Revision 1.1  1999/03/03 16:24:55  paulv
; Adapted from pressure_height.pro. Improved input argument checking.
;
;
;
;
;-

FUNCTION hypsometric2,          pressure, $          ; Input
                                temperature, $       ; Input
                                mixing_ratio, $      ; Input
                                surface_altitude, $  ; Input
                                altitude             ; Output



;------------------------------------------------------------------------------
;                             -- RCS Id keyword --
;------------------------------------------------------------------------------

  rcs_Id = 'Id: geopotential_altitude.pro,v 1.1 1999/03/03 16:24:55 paulv Exp'



;------------------------------------------------------------------------------
;                    -- Determine floating-point precision --
;------------------------------------------------------------------------------

  tolerance = ( MACHAR() ).EPS



;------------------------------------------------------------------------------
;                             -- Check input --
;------------------------------------------------------------------------------

  n_arguments = 5
  IF ( N_PARAMS() NE n_arguments ) THEN BEGIN
    MESSAGE, 'Invalid number of arguments', /INFO
    RETURN, -1
  ENDIF


; -----------------------------------------
; Check that required arguments are defined
; -----------------------------------------

  IF ( N_ELEMENTS( pressure ) EQ 0 ) THEN BEGIN
    MESSAGE, 'Input PRESSURE argument not defined!', /INFO
    RETURN, -1
  ENDIF

  IF ( N_ELEMENTS( temperature ) EQ 0 ) THEN BEGIN
    MESSAGE, 'Input TEMPERATURE argument not defined!', /INFO
    RETURN, -1
  ENDIF

  IF ( N_ELEMENTS( mixing_ratio ) EQ 0 ) THEN BEGIN
    MESSAGE, 'Input MIXING RATIO argument not defined!', /INFO
    RETURN, -1
  ENDIF

  IF ( N_ELEMENTS( surface_altitude ) EQ 0 ) THEN BEGIN
    MESSAGE, 'Input SURFACE ALTITUDE argument not defined!', /INFO
    RETURN, -1
  ENDIF


; ------------
; Check levels
; ------------

  n_levels = N_ELEMENTS( pressure )

  IF ( N_ELEMENTS( temperature ) NE n_levels OR $
       N_ELEMENTS( mixing_ratio ) NE n_levels ) THEN BEGIN
    MESSAGE, 'Inconsistent number of pressure/temperature/mixing ratio levels', /INFO
    RETURN, -1
  ENDIF

  IF ( n_levels LE 1 ) THEN BEGIN
    MESSAGE, 'Must specify AT LEAST two levels; surface and one other level.', /INFO
    RETURN, -1
  ENDIF


; --------------------------------------------------------------
; Only vectors can be passed in for pressure, temperature, and
; and mixing_ratio (no matrices or scalars). The "n_levels LE 1"
; check above will catch scalars but not matrices.
; --------------------------------------------------------------

  IF ( SIZE( REFORM( pressure ), /N_DIMENSIONS ) NE 1 OR $
       SIZE( REFORM( temperature ), /N_DIMENSIONS ) NE 1 OR $
       SIZE( REFORM( mixing_ratio ), /N_DIMENSIONS ) NE 1 ) THEN BEGIN
    MESSAGE, 'Pressure, temperature, and mixing_ratio inputs must be vectors.', /INFO
    RETURN, -1
  ENDIF


; ----------------------------------
; Check for pressures < or = zero
; ----------------------------------

  index = WHERE( pressure LT tolerance, count )

  IF ( count GT 0 ) THEN BEGIN
    MESSAGE, 'Input pressures < or = 0.0 found. Input units must be in hPa.', /INFO
    RETURN, -1
  ENDIF


; ----------------------------------
; Check for temperatures < or = zero
; ----------------------------------

  index = WHERE( temperature LT tolerance, count )

  IF ( count GT 0 ) THEN BEGIN
    MESSAGE, 'Input temperatures < or = 0.0 found. Input units must be in Kelvin.', /INFO
    RETURN, -1
  ENDIF


; ------------------------------
; Check for mixing ratios < zero
; ------------------------------

  index = WHERE( mixing_ratio LT 0.0, count )

  IF ( count GT 0 ) THEN BEGIN
    MESSAGE, 'Input mixing ratios < 0.0 found. Input units must be in g/kg.', /INFO
    RETURN, -1
  ENDIF


; ------------------------------------------------
; Check that surface altitude is a scalar quantity
; ------------------------------------------------

  IF ( N_ELEMENTS( surface_altitude ) GT 1 ) THEN BEGIN
    MESSAGE, 'Input surface altitude must be a scalar quantity.', /INFO
    RETURN, -1
  ENDIF


; --------------------------------
; Check for surface altitude < 0.0
; --------------------------------

  IF ( surface_altitude LT 0.0 ) THEN BEGIN
    MESSAGE, 'Surface altitude < 0.0.', /INFO
    RETURN, -1
  ENDIF



;------------------------------------------------------------------------------
;                      -- Declare some constants --
;
;  Parameter         Description                 Units
;  ---------   ---------------------------     -----------
;     Rd       Gas constant for dry air        J/degree/kg
;
;     g        Acceleration due to gravity       m/s^2
;
;    eps       Ratio of the molec. weights        None
;              of water and dry air
;              
;------------------------------------------------------------------------------

  Rd  = 286.9968933d
  g   = 9.80616d
  eps = 0.621970585d



;------------------------------------------------------------------------------
;            -- Sort data so that array start is the surface --
;------------------------------------------------------------------------------

; --------------------
; Calculate average dP
; --------------------

  dp_average = TOTAL( pressure[ 0 : n_levels - 2 ] - pressure( 1 : n_levels - 1 ) ) / FLOAT( n_levels - 1 )


; ---------------------------------------------------
; Sort arrays based on  average pressure differential
; ---------------------------------------------------

  IF ( dp_average LT 0.0 ) THEN BEGIN
    MESSAGE, 'Data being sorted in ascending(descending) altitude(pressure) order!', /INFO
    index = REVERSE( SORT( pressure ) )
    sort  = 1
  ENDIF ELSE BEGIN
    index = INDGEN( n_levels )
    sort  = 0
  ENDELSE

  p  = pressure[ index ]
  t  = temperature[ index ]
  mr = mixing_ratio[ index ]



;------------------------------------------------------------------------------
;      -- Create return height array and set up indexing for averages --
;------------------------------------------------------------------------------

  altitude      = FLTARR( n_levels )
  altitude[ 0 ] = surface_altitude

  index = INDGEN( n_levels - 1 ) + 1



;------------------------------------------------------------------------------
;                   -- Calculate average temperature --
;------------------------------------------------------------------------------

  t_average = 0.5 * ( t[ index ] + t[ index - 1 ] )



;------------------------------------------------------------------------------
;         -- Calculate average mixing ratio (in kg/kg - hence --
;         -- the divisor of 2000.0 instead of 2.0 )           --
;------------------------------------------------------------------------------

  mr_average = 0.0005 * ( mr[ index ] + mr[ index - 1 ] )



;------------------------------------------------------------------------------
;                   -- Calculate virtual temperature --
;------------------------------------------------------------------------------

  ratio     = ( 1.0d - eps ) / eps
  t_virtual = t_average * ( 1.0 + ( ratio * mr_average ) )



;------------------------------------------------------------------------------
;           -- Calculate altitudes (divide by 1000.0 to get km) --
;           -- Make sure the data is returned in an order       --
;           -- consistent with the input                        --
;------------------------------------------------------------------------------

; -- Calculate layer thicknesses

  altitude[ index ] =  0.001 * ( Rd / g ) * t_virtual * ALOG( p[ index - 1 ] / p[ index ] )


; -- Add up layer thicknesses

  FOR i = 1, n_levels - 1 DO altitude[ i ] = altitude[ i - 1 ] + altitude[ i ]


; -- Reverse array order if required

  IF ( sort EQ 1 ) THEN altitude = REVERSE( altitude )


  RETURN, 1

END
