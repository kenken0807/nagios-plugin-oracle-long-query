# nagios-plugin-oracle-long-query
Nagios plugin for oracle.
Monitored long/slow query

# options

```
  -h [ip addr]  Hostname or Ip address[default localhost]
  -P [port]     Port[default 1521]
  -u [username] DBconnect Username[default system]---must be able to access V$SESSION and V$SQLTEXT
  -p [password] Password
  -D [sid]      SID
  -w [secs]     Warning seconds[default 30]
  -l [secs]     Critical seconds[default 600]
  -c [username or username,username,..] Monitored user or users
  --help        Show Help
```

#sample
```
 usage: ./check_oracle_long_query.pl -h 192.168.1.1 -u system -p systempassword -D orcl -c oracleuser -w 30 -l 180
```
 
```
・nagios OK
$./check_oracle_long_query.pl -h 192.168.1.1 -u system -p systempassword -D orcl -c oracleuser -w 30 -l 180
OK
$ echo $?
0

・nagios warning
$./check_oracle_long_query.pl -h 192.168.1.1 -u system -p systempassword -D orcl -c oracleuser -w 30 -l 180
WARNING:  TIME= 164 SQL_ID=dm9b2ftx3qfsv SQL= BEGIN DBMS_LOCK.SLEEP(300); END;
$ echo $?
1

・nagios critical
$./check_oracle_long_query.pl -h 192.168.1.1 -u system -p systempassword -D orcl -c oracleuser -w 30 -l 180
CRITICAL:  TIME= 272 SQL_ID=dm9b2ftx3qfsv SQL= BEGIN DBMS_LOCK.SLEEP(300); END;
$ echo $?
2
```
