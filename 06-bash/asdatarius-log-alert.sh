#!/bin/bash

PATH_TO_LOGFILE=$1
PATH_TO_LOCKFILE=/tmp/asdatarius-log-alert.lock
PATH_TO_PROGRESS_STORAGE=/tmp/asdatarius-log-alert.progress
ALERT_EMAIL="vagrant@localhost"

# main usage through systemd service, so redundant
if ( set -o noclobber; echo "$$" > "$PATH_TO_LOCKFILE") 2> /dev/null; then
	trap 'rm -f "$PATH_TO_LOCKFILE"; exit $?' INT TERM EXIT
	
	if [[ ! -r $PATH_TO_LOGFILE ]]; then
		echo "File \"${PATH_TO_LOGFILE}\" must be readable"
		exit 1
	fi

	SIZE=$(stat --printf="%s" "${PATH_TO_LOGFILE}")

	if [[ ! -r $PATH_TO_PROGRESS_STORAGE ]]; then
		PREV_SIZE=0
	else
		PREV_SIZE=$(cat ${PATH_TO_PROGRESS_STORAGE})
	fi
	
	if [[ $SIZE -lt $PREV_SIZE ]]; then
		# log was rotated
		SIZE=0
		PREV_SIZE=0
	elif [[ $SIZE -eq $PREV_SIZE ]]; then
		# log still the same
		echo "File \"${PATH_TO_LOGFILE}\" still the same, skip!"
		exit 0
	fi

	echo ${SIZE} > ${PATH_TO_PROGRESS_STORAGE}

	((PREV_SIZE++))
	#skip empty lines with `awk 'NF'`, could affect calculation!
	START_DT=$(tail -c +${PREV_SIZE} ${PATH_TO_LOGFILE} | head -n1 | awk '{ print $4 $5 }')
	END_DT=$(tail -n1 ${PATH_TO_LOGFILE} | awk '{ print $4 $5 }')
	IPs=$(tail -c +${PREV_SIZE} ${PATH_TO_LOGFILE} | awk 'NF' | awk '{ print $1 }' | sort | uniq -c | sort -nr | head -n 10)
	# there are broken uri (no method/uri/protocol)
	URIs=$(tail -c +${PREV_SIZE} ${PATH_TO_LOGFILE} | awk 'NF' | awk -F'"' '{ print $2 }' | awk '{ if(length($2) != 0) { print $2 } else print "!!!BINGO BONGO!!!" }' | sort | uniq -c | sort -nr | head -n 10)
	# broken request part leads to broken numbering, so go for quote delimiter first
	ERR_CODEs=$(tail -c +${PREV_SIZE} ${PATH_TO_LOGFILE} | awk 'NF' | awk -F'"' '{ print $3 }' | awk '{print $1}' | grep -v '^[^45]' | sort | uniq -c | sort -nr)
	OK_CODEs=$(tail -c +${PREV_SIZE} ${PATH_TO_LOGFILE} | awk 'NF' | awk -F'"' '{ print $3 }' | awk '{print $1}' | grep -v '^[45]' | sort | uniq -c | sort -nr)


	/usr/sbin/sendmail -t 2> /dev/null <<LOGMAIL
To: ${ALERT_EMAIL}
From: systemd <root@${HOSTNAME}>
Subject: asdatarius-log-alert.service ${START_DT} - ${END_DT}
Content-Transfer-Encoding: 8bit
Content-Type: text/plain; charset=UTF-8

LOG:
${PATH_TO_LOGFILE}:${PREV_SIZE}-EOF

IP TOP:
${IPs}

URI TOP:
${URIs}

ERRORS:
${ERR_CODEs}

REQUESTS:
${OK_CODEs}

Your monitoring.
LOGMAIL

 	rm -f "${PATH_TO_LOCKFILE}"
 	trap - INT TERM EXIT
else
	echo "Failed to acquire lockfile: ${PATH_TO_LOCKFILE}."
	echo "Held by $(cat ${PATH_TO_LOCKFILE})"
	exit 1
fi