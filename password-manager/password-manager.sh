#!/bin/sh

set -e
trap bye_bye EXIT

#-------------------------------------------------------------------
# Password Manager
#
# Script to manage passwords in a pgp encrypted "database"
#-------------------------------------------------------------------

#-------------------------------------------------------------------
# Configuration:
#
# Set here your gpg userID to use the correct pgp key
USERID="<USER-ID>"
#
# Set here the location of your 'database':
DATABASE="<DATABASE>"
#
# Set here the pgp program to be used for encryption
PGP_PROGRAM="/usr/bin/gpg"
#-------------------------------------------------------------------

# Dependencies
DEPENDENCIES="tr fold"
OPT_CLIP_DEPENDENCIES="xsel xclip"

# Password-manager parameters
ACTIONS="add get list update delete generate"
ACTION=""
SERVICE=""
PASSWORD=""


bye_bye () {
    echo -e "\naborting..."
}

echoerr () {
    echo "$@" 1>&2
}

echo_prefixed () {
    for i in $2; do
        echo "$1$i"
    done
}

prompt () {
    echo -n "$1"
    read yn
    case "${yn}" in
        [Yy]*) return 0;;
        *) return 1;;
    esac
}

prompt_confirmation () {
    echo -e "-- $1 -- \n$2\n"
    prompt "Are you sure? [y/N]: "
}

not_in () {
    element="$1" && shift
    for i in $@; do
        if [ "$element" == "$i" ]; then
            return 1
        fi
    done
    return 0
}

display_help () {
    echo "usage: password-manager [action] [options]"
    echo
    echo "actions: [add get update delete generate]"
    echo -e "\t-h|--help: display this message"
    echo -e "\t-f|--file: path to database file"
    echo -e "\t-v|--version: output information about this software"
    echo -e "\t-s|--service: identifier associated with the password"
    return 0
}

check_opt_clipboard_dependencies () {
    installed=false
    for i in ${OPT_CLIP_DEPENDENCIES}; do
        if command -v "$i" 2>&1 >/dev/null; then
            installed=true
        fi
    done
    "${installed}" || echo "info: you may want to install one of these programs for automatic clipboard copying:  ${OPT_CLIP_DEPENDENCIES}"
}

check_pgp_program () {
    if [ ! -x "${PGP_PROGRAM}" ]; then
        echoerr "error: pgp program at ${PGP_PROGRAM} does not exist or is not executable"
        exit 9
    fi
}

check_dependencies () {
    for i in ${DEPENDENCIES}; do
        if ! command -v "$i" 2>&1 >/dev/null; then
            echoerr "error: $i is required by password-manager and must be installed"
            exit 7
        fi
    done
    check_pgp_program
    check_opt_clipboard_dependencies
}

check_if_database_exists () {
    if [ ! -f "$DATABASE" ]; then
        echoerr "password-manager: database at $DATABASE does not exist"
        exit 10
    fi
}

check_if_user_key_exists () {
    if ! "${PGP_PROGRAM}" --list-keys "$USERID" 2>&1 > /dev/null; then
        echoerr "password-manager: key for $USERID not present in PGP program database"
        exit 11;
    fi
}

prompt_missing_info () {
    if [ -z "$USERID" ]; then
        echo -n "GPG UserID: "
        read -r USERID
    fi

    if [ -z "$DATABASE" ]; then
        echo -n "Database path: "
        read -r DATABASE
    fi

    if [ "$ACTION" != "list" ]; then
        if [ -z "$SERVICE" ]; then
            echo -n "Service: "
            read SERVICE
        fi
    fi
}

parse_args () {
    if [ $# -eq 0 ]; then
        display_help
        exit 1
    fi
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -v|--version)
                echo "author: giovanifss"
                echo "source: https://github.com/giovanifss/Simple-Password-Manager"
                echo "license: MIT"
                echo "version: 0.2"
                exit 0;;
            -h|--help)
                display_help
                exit 0;;
            -f|--file)
                if [ -z "$2" ] || [[ "$2" == "-*" ]]; then
                    echoerr "error: expected argument after file option"
                    exit 3
                fi
                DATABASE="$2"
                shift;;
            -s|--service)
                if [ -z "$2" ] || [[ "$2" == "-*" ]]; then
                    echoerr "error: expected argument after service option"
                    exit 3
                fi
                SERVICE="$2"
                shift;;
            *)
                if [ ! -z "$ACTION" ] || [[ "$1" == "-*" ]]; then
                    echoerr "error: unknown argument '$1'"
                    exit 3
                fi
                if not_in "$1" "${ACTIONS}"; then
                    echoerr "password-manager: unsupported action '$1'"
                    echoerr "use -h or --help to see available actions"
                    exit 3
                fi
                ACTION="$1"
        esac
        shift
    done
    if [ -z "$ACTION" ]; then
        echoerr "password-manager: action not specified"
        echoerr "use -h or --help to see available actions"
        exit 3
    fi
}

clipboard_password () {
    password="$1"
    copied=false

    command -v xsel 2>&1 > /dev/null &&
        echo -n "${password}" | xsel -b &&
        copied=true

    if ! ${copied}; then
        command -v xclip 2>&1 > /dev/null &&
            echo -n "${password}" | xclip -sel clip &&
            copied=true
    fi

    if ${copied}; then
        echo "Password copied to clipboard!"
    else
        echo "info: xsel or xclip is needeed to copying to clipboard"
        echo "Password: ${password}"
    fi
}

backup_db () {
    dbpath="$1"
    newdb="$2"

    if [ -f "${dbpath}.bkp" ]; then
        cp "${dbpath}.bkp" "${dbpath}.bkp2"
    fi

    if [ -f "${dbpath}.bkp" ]; then
        rm "${dbpath}.bkp"
    fi

    mv "${dbpath}" "${dbpath}.bkp" &&
    mv "${newdb}" "${dbpath}"

    if [ -f "${dbpath}.bkp2" ]; then
        rm "${dbpath}.bkp2"
    fi
}

lock_db () {
    dbpath="$1"
    plaintext="$2"
    echo "${plaintext}" | "${PGP_PROGRAM}" --sign -r "$USERID" --output "${dbpath}" --encrypt
}

unlock_db () {
    dbpath="$1"
    "${PGP_PROGRAM}" --decrypt "${dbpath}" 2>/dev/null
}

list_services () {
    services=$(unlock_db "$DATABASE" | cut -d ' ' -f1 | cut -d ':' -f1)
    if [ -z "${services}" ]; then
        echoerr "password-manager: no services in database"
        exit 8
    fi
    echo "------ Services in database -----"
    echo_prefixed "- " "${services}"
}

query_password () {
    service_name="$1"
    PASSWORD=$(unlock_db "$DATABASE" | grep -i "${service_name}" | head -n1 | cut -d ' ' -f2)
    if [ -z "$PASSWORD" ]; then
        echoerr "password-manager: password for '${service_name}' not found"
        exit 6
    fi
    clipboard_password "$PASSWORD"
}

delete_password () {
    service_name="$1"
    tmp_dbname="/tmp/.db"

    cp "$DATABASE" "${tmp_dbname}"
    db_content=$(unlock_db "${tmp_dbname}") &&
        rm "${tmp_dbname}"

    lines=$(echo "${db_content}" | grep -i "${service_name}")

    prompt_confirmation "Lines to delete" "${lines}"
    lock_db "${tmp_dbname}" "$(echo "${db_content}" | grep -v -i "${service_name}")" &&
        unset db_content &&
        backup_db "$DATABASE" "${tmp_dbname}" &&
        echo "Password deleted"
}

update_password () {
    echo "password-manager: update action not implemented yet"
    exit 4
}

add_password () {
    service_name="$1"
    password="$2"
    tmp_dbname="/tmp/.db"

    cp "$DATABASE" "${tmp_dbname}"
    db_content=$(unlock_db "${tmp_dbname}") &&
        rm "${tmp_dbname}"

    db_content=$(echo -e "${db_content}\n${service_name}: ${password}")
    lock_db "${tmp_dbname}" "${db_content}" &&
        unset db_content &&
        backup_db "$DATABASE" "${tmp_dbname}"
}

generate_password () {
    echo -n "Number of characters: "
    read numchars
    PASSWORD=$(tr -dc 'A-Za-z0-9!"#$%&'\''()*+,-./:;<=>?@[\]^_`{|}~' < /dev/urandom | fold -w "${numchars}" | head -n1)
    add_password "$SERVICE" "$PASSWORD"
    clipboard_password "$PASSWORD"
}

main () {
    check_if_user_key_exists
    check_if_database_exists
    case "$ACTION" in
        add)
            echo -n "Password: "
            read -rs PASSWORD
            echo
            add_password "$SERVICE" "$PASSWORD"
            echo "Password added to database";;
        list)
            list_services;;
        get)
            query_password "$SERVICE";;
        update)
            update_password "$SERVICE";;
        delete)
            delete_password "$SERVICE";;
        generate)
            generate_password "$SERVICE";;
    esac
}

check_dependencies
parse_args $@
prompt_missing_info
main
