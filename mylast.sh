#!/bin/bash

LOG_FILE1="/var/log/auth.log"
LOG_FILE2="/var/log/auth.log.1"
LOG_FILE3="/var/log/auth.log.2.gz"
LOG_FILE4="/var/log/auth.log.3.gz"

output=""
format='+%Y-%m-%d %H:%M'
sinceDate=$(date --date="1 year ago" "$format")
tillDate=$(date --date="tomorrow" "$format")
presentDate="[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]"
lineMAX=-1

while getopts s:t:p:n: flag
do
    case "${flag}" in
        s) sinceDate=$(date --date="${OPTARG}" "$format");;
        t) tillDate=$(date --date="${OPTARG}" "$format");;
        p) presentDate=$(date --date="${OPTARG}" "$format");;
        n) lineMAX=${OPTARG};;
    esac
done
# echo "Since: $sinceDate"
# echo "Till: $tillDate"
# echo "Present: $presentDate"

parse_log(){
    local log_file=$1
    
    while read -r line; do
        timestamp=$(echo $line | awk '{print $1}')

        date=$(echo "$timestamp" | awk -F'T' '{print $1, $2}' | cut -d. -f1 | xargs -I {} date -d "{}" +"%a %b %d %H:%M")
        correctDate=$(date --date="$date" "$format")

        hostname=$(echo $line | awk '{print $2}')

        if [[ $correctDate > $sinceDate && $correctDate < $tillDate && $correctDate =~ $presentDate ]]; then
            # output+="$correctDate\n"
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
                output+="$date - LOGIN by user: $user (session: $session)\n"

            elif [[ "$message" =~ "Removed session" ]]; then
                session=$(echo "$message" | grep -oP 'session \K\w+')
                output+="$date - LOGOUT (session: $session)\n"

            elif [[ "$message" =~ "The system will suspend now!" ]]; then
                output+="$date - SYSTEM SUSPEND\n"

            elif [[ "$message" =~ "Operation 'suspend' finished" ]]; then
                output+="$date - SYSTEM RESUME\n"
            
            elif [[ "$message" =~ "System is powering down" ]]; then
                output+="$date - SYSTEM POWERDOWN\n"
            fi
        fi

    done < $1
}

parse_log $LOG_FILE2
parse_log $LOG_FILE1


output=$(echo -e "$output" | tac)

lineNR=-1
while IFS= read -r line; do
    ((lineNR++))
    if [[ $lineMAX == -1 || $lineNR -le $lineMAX && $lineNR -gt 0 ]]; then
        echo "$lineNR: $line"
    fi
done <<< "$output"
