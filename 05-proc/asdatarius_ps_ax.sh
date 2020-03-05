#!/bin/bash

echo "ps ax";
PIDS=($(ls /proc | grep '[0-9]' | sort -n));


printf "%-7s\t%-15s\t%-10s\t%-5s\t%s\n" "PID" "TTY" "STATUS" "TIME" "CMD"

for pid in ${PIDS[@]}
do
	# empty tty is possible
	if [ -e "/proc/$pid/fd/0" ]; then
		tty=$(readlink -f /proc/$pid/fd/0)
	else
		tty="?"
	fi

	# empty stat - no info, skip
	if [ -e /proc/$pid/stat ]; then
		stat=$(awk '{print $3}' /proc/$pid/stat 2>/dev/null);
		cputime=$(awk '{print $14+$15}' /proc/$pid/stat 2>/dev/null);
		starttime=$(awk '{print $22}' /proc/$pid/stat 2>/dev/null);
	else
		continue;
	fi

	# cmdline have more info, use stat if empty
	cmdline=$(cat /proc/$pid/cmdline 2>/dev/null | tr "\0" " ");
	if [[ -z "$cmdline" ]]; then
		cmdline=$(awk '{print $2}' /proc/$pid/stat 2>/dev/null);
	fi

	printf "%-7s\t%-15s\t%-10s\t%-5s\t%s\n" "$pid" "$tty" "$stat" "$cputime" "$cmdline";
done;
