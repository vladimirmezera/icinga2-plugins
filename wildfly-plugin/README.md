# Wildfly plugin

Nagios plugin for get JVM and Thread information from JBoss AS, Wildfly or JBoss EAP 6(7). This plugin uses management API (REST API).
The script returns status and performance data. Plugin calls application servers by curl command. If reponse (HTTP status code) is from 200 to 300 than return OK and performance data. Otherwise return ERROR with http status. 

## Run in domain mode
```shell
./check_wildfly.sh -u user -p userpassword -a http://server_url:19990 -s server_name -c controller_name

```

## Run in standalone mode

```shell
./check_wildfly.sh -u user -p userpassword -a http://server_url:19990 

```
