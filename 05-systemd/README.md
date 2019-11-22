## systemd
### Log monitoring service (with timer and variables).

- Create config `/etc/sysconfig/asdatarius-watchlog`

````bash
# Configuration file for my watchdog service
# Place it to /etc/sysconfig

# File and word in that file that we will be monit
WORD="ALERT"
LOG_FILE="/var/log/asdatarius-watchlog.log"
````

- Create logfile `/var/log/asdatarius-watchlog.log`

````
Some shitty log with AL3rTZ.
Every line could be complete fail.
Disaster.
alert!
````

- Create monitoring script `/opt/asdatarius-watchlog.sh` (chmod u+x) with basic validation

````bash
#!/bin/bash
WORD=$1
LOG_FILE=$2
DATE=`date`

function usage {
    echo "usage: sh $0 STR_TO_FIND FULL_PATH_TO_LOG"
    exit 1
}

if [ -f "$LOG_FILE" ]; then
    if [ -z "$WORD" ]
    then
        echo "Can't search for an empty substring."
	usage
    else
        if grep $WORD $LOG_FILE &> /dev/null
	then
            logger "$DATE: bingo bongo!"
        fi
        exit 0
    fi
else
    echo "The file '$LOG_FILE' does not exist."
    usage
fi
````

- Create service `/etc/systemd/system/asdatarius-watch.service`

````bash
[Unit]
Description="asdatarius watchlog service"

[Service]
Type=oneshot
EnvironmentFile=/etc/sysconfig/asdatarius-watchlog
ExecStart=/opt/asdatarius-watchlog.sh $WORD $LOG_FILE
````

- Test run

````
systemctl start asdatarius-watch.service; tail -n3 /var/log/messages
Nov 22 00:07:23 localhost systemd: Starting "asdatarius watchlog service"...
Nov 22 00:07:23 localhost root: Fri Nov 22 00:07:23 UTC 2019: bingo bongo!
Nov 22 00:07:23 localhost systemd: Started "asdatarius watchlog service".
````

- Create timer `/etc/systemd/system/asdatarius-watch.timer`

````bash
[Unit]
Description="Run watchlog script every 30 second"
# Without it timer won't start by himself and waits for manual service run
Requires=asdatarius-watch.service

[Timer]
# Run every 30 second
OnUnitActiveSec=30s
# Default accuracy - up to 1m
AccuracySec=1s
# Could be omitted if unit with same name (except suffix).
#Unit=asdatarius-watch.service

[Install]
WantedBy=multi-user.target
````	

- Timer just works

````bash
systemctl start asdatarius-watch.timer
````

- Final test

````bash
# I've used 5+1s accuracy for tests.
[root@asdatarius-systemd system]# tail -n10 /var/log/messages
Nov 22 00:00:15 localhost systemd: Started "asdatarius watchlog service".
Nov 22 00:00:21 localhost systemd: Starting "asdatarius watchlog service"...
Nov 22 00:00:21 localhost root: Fri Nov 22 00:00:21 UTC 2019: bingo bongo!
Nov 22 00:00:21 localhost systemd: Started "asdatarius watchlog service".
Nov 22 00:00:27 localhost systemd: Starting "asdatarius watchlog service"...
Nov 22 00:00:27 localhost root: Fri Nov 22 00:00:27 UTC 2019: bingo bongo!
Nov 22 00:00:27 localhost systemd: Started "asdatarius watchlog service".
Nov 22 00:00:33 localhost systemd: Starting "asdatarius watchlog service"...
Nov 22 00:00:33 localhost root: Fri Nov 22 00:00:33 UTC 2019: bingo bongo!
Nov 22 00:00:33 localhost systemd: Started "asdatarius watchlog service".
````

### Convert init file for spawn-fcgi to unit file

- Install spawn-fcgi and dependicies

````bash
yum install epel-release -y && yum install spawn-fcgi php php-cli mod_fcgid httpd -y
````

- Source config could be found here: `/etc/rc.d/init.d/spawn-fcgi`

- Prepare vars at `/etc/sysconfig/spawn-fcgi` (exists)

````bash
SOCKET=/var/run/php-fcgi.sock
OPTIONS="-u apache -g apache -s $SOCKET -S -M 0600 -C 32 -F 1 -- /usr/bin/php-cgi"
````

- Create unit file `/etc/systemd/system/spawn-fcgi.service`

````bash
[Unit]
Description=Spawn-fcgi startup service by Otus
After=network.target

[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/sysconfig/spawn-fcgi
ExecStart=/usr/bin/spawn-fcgi -n $OPTIONS
KillMode=process

[Install]
WantedBy=multi-user.target
````

- Final test
````bash
systemctl start spawn-fcgi
systemctl status spawn-fcgi
● spawn-fcgi.service - Spawn-fcgi startup service
   Loaded: loaded (/etc/systemd/system/spawn-fcgi.service; disabled; vendor preset: disabled)
   Active: active (running) since Fri 2019-11-22 01:11:09 UTC; 2s ago
 Main PID: 19427 (php-cgi)
   CGroup: /system.slice/spawn-fcgi.service
           ├─19427 /usr/bin/php-cgi
           ├─19428 /usr/bin/php-cgi
           ├─19429 /usr/bin/php-cgi
           ├─19430 /usr/bin/php-cgi
           ├─19431 /usr/bin/php-cgi
           ├─19432 /usr/bin/php-cgi
           ├─19433 /usr/bin/php-cgi
           ├─19434 /usr/bin/php-cgi
           ├─19435 /usr/bin/php-cgi
           ├─19436 /usr/bin/php-cgi
           ├─19437 /usr/bin/php-cgi
           ├─19438 /usr/bin/php-cgi
           ├─19439 /usr/bin/php-cgi
           ├─19440 /usr/bin/php-cgi
           ├─19441 /usr/bin/php-cgi
           ├─19442 /usr/bin/php-cgi
           ├─19443 /usr/bin/php-cgi
           ├─19444 /usr/bin/php-cgi
           ├─19445 /usr/bin/php-cgi
           ├─19446 /usr/bin/php-cgi
           ├─19447 /usr/bin/php-cgi
           ├─19448 /usr/bin/php-cgi
           ├─19449 /usr/bin/php-cgi
           ├─19450 /usr/bin/php-cgi
           ├─19451 /usr/bin/php-cgi
           ├─19452 /usr/bin/php-cgi
           ├─19453 /usr/bin/php-cgi
           ├─19454 /usr/bin/php-cgi
           ├─19455 /usr/bin/php-cgi
           ├─19456 /usr/bin/php-cgi
           ├─19457 /usr/bin/php-cgi
           ├─19458 /usr/bin/php-cgi
           └─19459 /usr/bin/php-cgi
````

### Templates for httpd unit
Prepare unit for multiconfig httpd setup.

- Copy base unit

````bash
cp /usr/lib/systemd/system/httpd.service /etc/systemd/system/httpd@.service
````

- Prepare unit file (add tpl var)

````bash
[Unit]
Description=The Apache HTTP Server
After=network.target remote-fs.target nss-lookup.target
Documentation=man:httpd(8)
Documentation=man:apachectl(8)

[Service]
Type=notify
# Configs with name httd-%I, control valid names!
EnvironmentFile=/etc/sysconfig/httpd-%I 
ExecStart=/usr/sbin/httpd $OPTIONS -DFOREGROUND
ExecReload=/usr/sbin/httpd $OPTIONS -k graceful
ExecStop=/bin/kill -WINCH ${MAINPID}
KillSignal=SIGCONT
PrivateTmp=true

[Install]
WantedBy=multi-user.target
````

- Add settings files for 2 example instances `/etc/sysconfig/httpd-first` and `/etc/sysconfig/httpd-second` (custom configs with different ports/pids)

````bash
# /etc/sysconfig/httpd-first
OPTIONS=-f conf/first.conf

# /etc/sysconfig/httpd-second
OPTIONS=-f conf/second.conf
````

- Config could be copied from original `/etc/httpd/conf/httpd.conf`, important part - pid and port:
````bash
# /etc/httpd/conf/httpd-first.conf
...
Listen 8081
PidFile /var/run/httpd-first.pid
...

# /etc/httpd/conf/httpd-second.conf
...
Listen 8082
PidFile /var/run/httpd-second.pid
...
````

- Final test

````bash
systemctl start httpd@first
systemctl status httpd@first
● httpd@first.service - The Apache HTTP Server with custom configs
   Loaded: loaded (/etc/systemd/system/httpd@.service; disabled; vendor preset: disabled)
   Active: active (running) since Fri 2019-11-22 01:22:07 UTC; 9s ago
     Docs: man:httpd(8)
           man:apachectl(8)
 Main PID: 19491 (httpd)
   Status: "Total requests: 0; Current requests/sec: 0; Current traffic:   0 B/sec"
   CGroup: /system.slice/system-httpd.slice/httpd@first.service
           ├─19491 /usr/sbin/httpd -f conf/first.conf -DFOREGROUND
           ├─19492 /usr/sbin/httpd -f conf/first.conf -DFOREGROUND
           ├─19493 /usr/sbin/httpd -f conf/first.conf -DFOREGROUND
           ├─19494 /usr/sbin/httpd -f conf/first.conf -DFOREGROUND
           ├─19495 /usr/sbin/httpd -f conf/first.conf -DFOREGROUND
           ├─19496 /usr/sbin/httpd -f conf/first.conf -DFOREGROUND
           └─19497 /usr/sbin/httpd -f conf/first.conf -DFOREGROUND

Nov 22 01:22:07 asdatarius-systemd systemd[1]: Starting The Apache HTTP Server with custom configs...
Nov 22 01:22:07 asdatarius-systemd httpd[19491]: AH00558: httpd: Could not reliably determine the server's fully qualified domain name, using 127.0.0.1. Set the 'ServerName' directive global... this message
Nov 22 01:22:07 asdatarius-systemd systemd[1]: Started The Apache HTTP Server with custom configs.
Hint: Some lines were ellipsized, use -l to show in full.


systemctl start httpd@second
systemctl status httpd@second
● httpd@second.service - The Apache HTTP Server with custom configs
   Loaded: loaded (/etc/systemd/system/httpd@.service; disabled; vendor preset: disabled)
   Active: active (running) since Fri 2019-11-22 01:22:38 UTC; 2s ago
     Docs: man:httpd(8)
           man:apachectl(8)
 Main PID: 19507 (httpd)
   Status: "Processing requests..."
   CGroup: /system.slice/system-httpd.slice/httpd@second.service
           ├─19507 /usr/sbin/httpd -f conf/second.conf -DFOREGROUND
           ├─19508 /usr/sbin/httpd -f conf/second.conf -DFOREGROUND
           ├─19509 /usr/sbin/httpd -f conf/second.conf -DFOREGROUND
           ├─19510 /usr/sbin/httpd -f conf/second.conf -DFOREGROUND
           ├─19511 /usr/sbin/httpd -f conf/second.conf -DFOREGROUND
           ├─19512 /usr/sbin/httpd -f conf/second.conf -DFOREGROUND
           └─19513 /usr/sbin/httpd -f conf/second.conf -DFOREGROUND

Nov 22 01:22:38 asdatarius-systemd systemd[1]: Starting The Apache HTTP Server with custom configs...
Nov 22 01:22:38 asdatarius-systemd httpd[19507]: AH00558: httpd: Could not reliably determine the server's fully qualified domain name, using 127.0.0.1. Set the 'ServerName' directive global... this message
Nov 22 01:22:38 asdatarius-systemd systemd[1]: Started The Apache HTTP Server with custom configs.
Hint: Some lines were ellipsized, use -l to show in full.
````
