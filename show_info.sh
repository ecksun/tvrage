#!/bin/bash
# This is a simple bash script that interacts with the tvrage api
# 
# Copyright 2011 Linus Wallgren
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


shopt -s nocasematch

function show_help() {
    echo '
        Usage: show_serie [OPTION]... PATTERN
        Show information about a series
        If it is preconfigured and an exact match, only that show will be
        listed, otherwise it will list all preconfigured shows that match.
        If nothing preconfigured can be found, it will search tvrage.

        -h, --help          Show this help
        -s, --search        Explicity search for a series
        -n, --search-hits   Specify the number of hits, default 1. Set it to -1
                            to disable the limit and 0 to have it automatically
                            calculated depending on screen height
    ';
}

search_hits=1
while [[ $1 == -* ]]; do 
    case "$1" in 
        -h|--help)show_help; exit 0;;
        -s|--search)do_search=true;;
        -n|--search-hits) 
            if (($# > 1)); then
                search_hits=$2
                shift
            else
                echo "--search-hits requires an argument"
                show_help
                exit 1
            fi
    esac
    shift
done

if (($# == 0)); then
    echo "A pattern is required"
    show_help
    exit 1
fi

if [ $search_hits == 0 ]; then
    rows=`tput lines`
    let search_hits=$rows/7
fi

show=$*

declare -A shows

shows[Doctor.Who]='Doctor Who (2005)'

# This function is dependant on $showinfo
function get_tag() {
    echo `grep "$*" <<< "$showinfo" | awk -F '@' '{ print $2 }' | sed 's/\^/ - /g'`
}

# requires a parameter
function show_info() {
    showinfo=`GET "http://services.tvrage.com/tools/quickinfo.php?show=$*"`

    echo "
Show:               $(get_tag 'Show Name')
ID:                 $(get_tag 'Show ID')
Link:               $(get_tag 'Show URL')
Status:             $(get_tag 'Status')
Latest Episode:     $(get_tag 'Latest Episode')
Next Episode:       $(get_tag 'Next Episode')"
}


# In case we dont want to search
if [ ! $do_search ]; then
    # Otherwise search all preconfigured shows and display them
    if [ -z "${shows[$show]}" ]; then
        regex=`sed 's/ /./g' <<< $show`

        do_search=true
        regex=".*$regex.*"

        for key in "${!shows[@]}"; do
            if [[ $key =~ $regex ]]; then
                show_info ${shows[$key]}
                unset do_search
                ((search_hits--))
                if [ $search_hits == 0 ]; then
                    exit 0
                fi
            fi
        done
    # If we didnt want to search, check if we have preconfigured the show id exactly
    else
        show_info ${shows[$show]}
        ((search_hits--))
    fi
fi

# Search tvrage if either -s is specified or the user has specified to
# automatically get the number of search results (-n 0).
if [ $do_search ] || [ $search_hits -gt 0 ]; then
    search_result=`GET "http://services.tvrage.com/feeds/search.php?show=$show"`

    # Remove the newline and split per show instad
    search_result=`tr -d '\n' <<< "$search_result" | awk 'BEGIN { RS="<show>"; FS="\n" } { print }' | tail -n +2`
    IFS=$'\n'
    while read -r showinfo; do
        if [ $search_hits == 0 ]; then
            break;
        fi
        ((search_hits--))
        [[ $showinfo =~ "name>"(.*)"</name" ]]
        show_info "${BASH_REMATCH[1]}"
    done <<< "$search_result";
    unset IFS

fi
