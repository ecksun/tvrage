#!/bin/bash

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


# In case we dont want to search and the user hasnt defined to get all results (-n -1)
if [ ! $do_search ] && [ ! $search_hits -eq -1 ]; then
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
    fi
fi

# Search tvrage if either -s is specified or the user has specified more search
# results (either > 0 or all, -1)
if [ $do_search ] || [ $search_hits -gt 0 ] || [ $search_hits -eq -1 ]; then
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
