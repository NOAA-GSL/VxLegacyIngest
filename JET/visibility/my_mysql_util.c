#include <stdio.h>
#include "mysql.h"
#include "my_mysql_util.h"

MYSQL *
do_connect(char *host_name, char *user_name, char *password,
	   char *db_name, unsigned int port_num, char *socket_name,
	   unsigned int flags) {
  MYSQL  *conn;

  conn = mysql_init(NULL);
  if(conn == NULL) {
    print_error(conn,"mysql_init failed\n");
    return(NULL);
  }
  if(mysql_real_connect(
			conn,
			host_name,
			user_name,
			password,
			db_name,
			0,
			NULL,
			0) == NULL) {
    print_error(conn,"mysql_real_connect failed:");
    return(NULL);
  }
  return(conn);
}

void do_disconnect(MYSQL *conn) {
  mysql_close(conn);
}

void print_error(MYSQL *conn, char *message) {
  fprintf(stdout, "%s\n",message);
  if(conn != NULL) {
    fprintf(stdout,"Error %u (%s)\n",
	    mysql_errno(conn),mysql_error(conn));
  }
}
