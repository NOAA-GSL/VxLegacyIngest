typedef struct grid {
  char mapproj[64];
  int nlat;
  int nlon;
  double swlat;
  double swlon;
  double nelat;
  double nelon;
  double dlat;
  double dlon;
  double missing_value;
} GRID;

