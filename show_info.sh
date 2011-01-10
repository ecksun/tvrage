#!/bin/bash

shopt -s nocasematch

function show_help() {
    # TODO
    echo '
        Usage: show_serie [OPTION]... PATTERN
        Show information about a series
        If it is preconfigured and an exact match, only that show will be
        listed, otherwise it will list all preconfigured shows that match.
        If nothing preconfigured can be found, it will search tvrage.

        -h, --help      Show this help
        -s, --search    Explicity search for a series
    ';
}

while [[ $1 == -* ]]; do 
    case "$1" in 
        -h|--help)show_help; exit 0;;
        -s|--search)do_search=true;;
    esac
    shift
done

show=$*

declare -A shows

shows[Doctor.Who]=3332

# This function is dependant on $showinfo
function get_tag() {
    [[ $showinfo =~ "$1>"(.*)"</$1" ]]
    echo ${BASH_REMATCH[1]}
}

# requires a parameter
function show_info() {
    showinfo=`GET http://services.tvrage.com/feeds/showinfo.php?sid=$1`

    echo "
Show:   $(get_tag showname)
ID:     $(get_tag showid)
Link:   $(get_tag showlink)
Status: $(get_tag status)"
}

function show_info_episodes() {
    show_info $1
    echo "episodes"
}


# In case we want to search
if [ ! $do_search ]; then
    # Otherwise search all preconfigured shows and display them
    if [ -z ${shows[$show]} ]; then
        regex=`sed 's/ /./g' <<< $show`

        do_search=true
        regex=".*$regex.*"

        for key in "${!shows[@]}"; do
            if [[ $key =~ $regex ]]; then
                show_info ${shows[$key]}
                unset do_search
            fi
        done
    # If we didnt want to search, check if we have preconfigured the show id exactly
    else
        show_info_episodes ${shows[$show]}
    fi
fi

if [ $do_search ]; then
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
        show_info $(get_tag showid)
    done <<< "$search_result";
    unset IFS

fi
