#!/bin/bash

show=$1

declare -A shows

shows[Doctor.Who]=3332

# This function is dependant on $showinfo
function get_tag() {
    [[ $showinfo =~ "$1>"(.*)"</$1" ]]
    echo ${BASH_REMATCH[1]}
}

if [ -z ${shows[$show]} ]; then
    search_result=`GET "http://services.tvrage.com/feeds/search.php?show=$show"`

    # Remove the newline and split per show instad
    search_result=`tr -d '\n' <<< "$search_result" | awk 'BEGIN { RS="<show>"; FS="\n" } { print }' | tail -n +2`
    IFS=$'\n'
    rows=`tput lines`
    let shows=$rows/4
    while read -r showinfo; do
        if [ $shows == 0 ]; then
            break;
        fi
        ((shows--))
        echo "
Name:   $(get_tag name)
ID:     $(get_tag showid)
Status: $(get_tag status)"
    done <<< "$search_result";
    unset IFS
else

showinfo=`GET http://services.tvrage.com/feeds/showinfo.php?sid=${shows[$show]}`

echo "
Show:   $(get_tag showname)
Link:   $(get_tag showlink)
Status: $(get_tag status)
"
fi
