#define MAXTAILS 10000          /* max num of tns for special lists below */
#define BADOBSFLAG 99999
#define MISSING 99999
#define MAX_LEVELS 200
#define AIRPORT_ID_LEN 6

typedef struct AIRPORT {
  char name[AIRPORT_ID_LEN];
  int id;
  int wmo_id;
  float lat;
  float lon;
  float elev;
  char line[100]; /* has the WHOLE line (including id and name) */      
} AIRPORT;

typedef struct raob_data_struct {
  long fr,pr,ht,tp,dp,wd,ws,clwmr,rwmr,snmr,icmr,grmr;
} raob_data_struct;

