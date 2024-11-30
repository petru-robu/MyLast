#!/bin/bash

LOG_FILE1="/var/log/auth.log"
LOG_FILE2="/var/log/auth.log.1"
LOG_FILE3="/var/log/auth.log.2.gz"
LOG_FILE4="/var/log/auth.log.3.gz"

parse_log(){
    local log_file=$1
    
    while read -r line; do
        timestamp=$(echo $line | awk '{print $1}')

        date=$(echo "$timestamp" | awk -F'T' '{print $1, $2}' | cut -d. -f1 | xargs -I {} date -d "{}" +"%a %b %d %H:%M")

        hostname=$(echo $line | awk '{print $2}')

        proc=$(echo $line | awk '{
            proc="";
            for (i = NF; i > 0; i--) 
            {
                if (index($i, ":") > 0) 
                {
                    break;
                }
            }
            for (j = 3; j<=i; j++){
                proc=proc $j;
            }
            print proc;
        }')

        message=$(echo $line | awk '{
            for (i = NF; i > 0; i--) 
            {
                if (index($i, ":") > 0) 
                {
                    break;
                }
            }
            print substr($0, index($0, $(i+1)));
        '})

        if [[ "$message" =~ "New session" && "$message" =~ "of user" ]]; then
            user=$(echo "$message" | grep -oP 'of user \K\w+')
            session=$(echo "$message" | grep -oP 'session \K\w+')
            echo "$date - LOGIN by user: $user (session: $session)"

        elif [[ "$message" =~ "Removed session" ]]; then
            session=$(echo "$message" | grep -oP 'session \K\w+')
            echo "$date - LOGOUT (session: $session)"

        elif [[ "$message" =~ "The system will suspend now!" ]]; then
            echo "$date - SYSTEM SUSPEND"

        elif [[ "$message" =~ "Operation 'suspend' finished" ]]; then
            echo "$date - SYSTEM RESUME"
        
        elif [[ "$message" =~ "System is powering down" ]]; then
            echo "$date - SYSTEM POWERDOWN"
        fi

    done < $1
}

parse_log $LOG_FILE2
parse_log $LOG_FILE1

