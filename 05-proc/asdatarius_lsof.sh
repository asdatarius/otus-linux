#!/bin/bash

echo "lsof - List Open Files (recreated from /proc)"
echo ""

PIDS=($(ls /proc | grep '^[0-9]\+$' | sort -n))

printf "%-15s %-7s %-10s %-5s %-8s %-10s %-10s %-8s %s\n" "COMMAND" "PID" "USER" "FD" "TYPE" "DEVICE" "SIZE/OFF" "NODE" "NAME"

for pid in ${PIDS[@]}
do
    # Skip if process no longer exists
    if [ ! -d "/proc/$pid" ]; then
        continue
    fi

    # Get command name (truncate to 15 chars to match lsof)
    if [ -f "/proc/$pid/comm" ]; then
        command=$(cat /proc/$pid/comm 2>/dev/null | head -c 15)
    else
        command="?"
    fi

    # Get user ID and convert to username
    if [ -f "/proc/$pid/status" ]; then
        uid=$(grep '^Uid:' /proc/$pid/status 2>/dev/null | awk '{print $2}')
        if [ -n "$uid" ]; then
            user=$(getent passwd "$uid" 2>/dev/null | cut -d: -f1)
            [ -z "$user" ] && user="$uid"
        else
            user="?"
        fi
    else
        user="?"
    fi

    # Current working directory
    if [ -e "/proc/$pid/cwd" ]; then
        cwd=$(readlink -f /proc/$pid/cwd 2>/dev/null)
        if [ -n "$cwd" ] && [ -e "$cwd" ]; then
            stat_info=$(stat -c "%t,%T %s %i" "$cwd" 2>/dev/null)
            device=$(echo "$stat_info" | awk '{print $1}')
            size=$(echo "$stat_info" | awk '{print $2}')
            inode=$(echo "$stat_info" | awk '{print $3}')

            if [ -d "$cwd" ]; then
                ftype="DIR"
            elif [ -f "$cwd" ]; then
                ftype="REG"
            else
                ftype="?"
            fi

            printf "%-15s %-7s %-10s %-5s %-8s %-10s %-10s %-8s %s\n" \
                "$command" "$pid" "$user" "cwd" "$ftype" "$device" "$size" "$inode" "$cwd"
        fi
    fi

    # Root directory
    if [ -e "/proc/$pid/root" ]; then
        root=$(readlink -f /proc/$pid/root 2>/dev/null)
        if [ -n "$root" ] && [ -e "$root" ]; then
            stat_info=$(stat -c "%t,%T %s %i" "$root" 2>/dev/null)
            device=$(echo "$stat_info" | awk '{print $1}')
            size=$(echo "$stat_info" | awk '{print $2}')
            inode=$(echo "$stat_info" | awk '{print $3}')

            printf "%-15s %-7s %-10s %-5s %-8s %-10s %-10s %-8s %s\n" \
                "$command" "$pid" "$user" "rtd" "DIR" "$device" "$size" "$inode" "$root"
        fi
    fi

    # Executable
    if [ -e "/proc/$pid/exe" ]; then
        exe=$(readlink -f /proc/$pid/exe 2>/dev/null)
        if [ -n "$exe" ] && [ -e "$exe" ]; then
            stat_info=$(stat -c "%t,%T %s %i" "$exe" 2>/dev/null)
            device=$(echo "$stat_info" | awk '{print $1}')
            size=$(echo "$stat_info" | awk '{print $2}')
            inode=$(echo "$stat_info" | awk '{print $3}')

            printf "%-15s %-7s %-10s %-5s %-8s %-10s %-10s %-8s %s\n" \
                "$command" "$pid" "$user" "txt" "REG" "$device" "$size" "$inode" "$exe"
        fi
    fi

    # File descriptors
    if [ -d "/proc/$pid/fd" ]; then
        for fd in /proc/$pid/fd/*; do
            if [ -e "$fd" ]; then
                fd_num=$(basename "$fd")
                fd_target=$(readlink -f "$fd" 2>/dev/null)

                if [ -z "$fd_target" ]; then
                    continue
                fi

                # Determine file type and mode
                if [ -p "$fd_target" ]; then
                    ftype="FIFO"
                    device="-"
                    size="-"
                    inode="-"
                    fname="$fd_target"
                elif [ -S "$fd_target" ]; then
                    ftype="unix"
                    device="-"
                    size="-"
                    # Get socket inode
                    inode=$(stat -c "%i" "$fd" 2>/dev/null || echo "-")
                    fname="$fd_target"
                elif [ -c "$fd_target" ]; then
                    ftype="CHR"
                    stat_info=$(stat -c "%t,%T 0 %i" "$fd_target" 2>/dev/null)
                    device=$(echo "$stat_info" | awk '{print $1}')
                    size="0"
                    inode=$(echo "$stat_info" | awk '{print $3}')
                    fname="$fd_target"
                elif [ -b "$fd_target" ]; then
                    ftype="BLK"
                    stat_info=$(stat -c "%t,%T 0 %i" "$fd_target" 2>/dev/null)
                    device=$(echo "$stat_info" | awk '{print $1}')
                    size="0"
                    inode=$(echo "$stat_info" | awk '{print $3}')
                    fname="$fd_target"
                elif [ -d "$fd_target" ]; then
                    ftype="DIR"
                    stat_info=$(stat -c "%t,%T %s %i" "$fd_target" 2>/dev/null)
                    device=$(echo "$stat_info" | awk '{print $1}')
                    size=$(echo "$stat_info" | awk '{print $2}')
                    inode=$(echo "$stat_info" | awk '{print $3}')
                    fname="$fd_target"
                elif [ -f "$fd_target" ]; then
                    ftype="REG"
                    stat_info=$(stat -c "%t,%T %s %i" "$fd_target" 2>/dev/null)
                    device=$(echo "$stat_info" | awk '{print $1}')
                    size=$(echo "$stat_info" | awk '{print $2}')
                    inode=$(echo "$stat_info" | awk '{print $3}')
                    fname="$fd_target"
                else
                    # Check if it's a network socket
                    if [[ "$fd_target" =~ ^socket:\[([0-9]+)\]$ ]]; then
                        ftype="IPv4"
                        device="-"
                        size="-"
                        inode="${BASH_REMATCH[1]}"
                        # Try to get socket info from /proc/net/tcp or /proc/net/udp
                        fname="$fd_target"
                    elif [[ "$fd_target" =~ ^pipe:\[([0-9]+)\]$ ]]; then
                        ftype="FIFO"
                        device="-"
                        size="-"
                        inode="${BASH_REMATCH[1]}"
                        fname="pipe"
                    else
                        ftype="?"
                        device="-"
                        size="-"
                        inode="-"
                        fname="$fd_target"
                    fi
                fi

                # Get file descriptor mode (read/write)
                if [ -f "/proc/$pid/fdinfo/$fd_num" ]; then
                    flags=$(grep '^flags:' "/proc/$pid/fdinfo/$fd_num" 2>/dev/null | awk '{print $2}')
                    # Simple approximation: odd flags usually mean write mode
                    if [ -n "$flags" ]; then
                        mode_suffix="u"  # unknown/both
                    else
                        mode_suffix="u"
                    fi
                else
                    mode_suffix="u"
                fi

                fd_display="${fd_num}${mode_suffix}"

                printf "%-15s %-7s %-10s %-5s %-8s %-10s %-10s %-8s %s\n" \
                    "$command" "$pid" "$user" "$fd_display" "$ftype" "$device" "$size" "$inode" "$fname"
            fi
        done
    fi

    # Memory mapped files (limit output to avoid overwhelming)
    if [ -f "/proc/$pid/maps" ]; then
        # Get unique mapped files (excluding anonymous mappings)
        mapped_files=$(awk '$6 != "" && $6 !~ /^\[/ {print $6}' /proc/$pid/maps 2>/dev/null | sort -u | head -5)

        for mapped_file in $mapped_files; do
            if [ -e "$mapped_file" ]; then
                stat_info=$(stat -c "%t,%T %s %i" "$mapped_file" 2>/dev/null)
                device=$(echo "$stat_info" | awk '{print $1}')
                size=$(echo "$stat_info" | awk '{print $2}')
                inode=$(echo "$stat_info" | awk '{print $3}')

                printf "%-15s %-7s %-10s %-5s %-8s %-10s %-10s %-8s %s\n" \
                    "$command" "$pid" "$user" "mem" "REG" "$device" "$size" "$inode" "$mapped_file"
            fi
        done
    fi

done | head -100  # Limit output to avoid overwhelming terminal

echo ""
echo "Note: Output limited to first 100 lines. Real lsof would show all entries."
