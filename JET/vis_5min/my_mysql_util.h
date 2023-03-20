MYSQL *
do_connect(char *host_name, char *user_name, char *password,
	   char *db_name, unsigned int port_num, char *socket_name,
	   unsigned int flags);
void do_disconnect(MYSQL *conn);
void print_error(MYSQL *conn, char *message);
void process_result_set(MYSQL *conn, MYSQL_RES *res_set);
