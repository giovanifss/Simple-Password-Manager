#!/bin/bash

set -euo pipefail

#-------------------------------------------------------------------
# Password Manager
#
# Script to manage the password in a pgp encrypted "database"
#-------------------------------------------------------------------

#-------------------------------------------------------------------
# Configuration:
#
# Set here your gpg userID to use the correct pgp key
USERID="<USER-ID>"
#
# Set here the location of your 'database':
DATABASE="<DATABASE>"
#-------------------------------------------------------------------

ACTIONS=(add get list update delete generate) # Script actions
ACTION=""             # The desired action to execute
SERVICE=""            # The service where the password is used
PASSWORD=""           # The generated/inputed password

# Setting colors for better visualization
green=$(tput setaf 2)
orange=$(tput setaf 3)
red=$(tput setaf 1)
normal=$(tput sgr0)

# Setting special characters for better visualization
tick="${green}[✔]${normal}"
mark="${red}[✖]${normal}"
exc="${orange}[!]${normal}"

function echoerr () {
  cat <<< "$@" 1>&2
}

function echo_prefixed () {
  prefix="$1" && shift
  elements=("$@")

  for i in ${elements[*]}; do
    echo "$prefix $i"
  done
}

function prompt_confirmation () {
  lines="$1"
  message="$2"
  echo -e "$exc -- $message -- $exc\n$lines\n"
  read -r -p "$exc Are you sure? [y/N]: " response
  case "$response" in
    [yY][eE][sS]|[yY]) 
      return 0;;
    *)
      return 1;;
  esac
}

function not_in () {
  element=$1 && shift
  array=("$@")

  for i in ${array[*]}; do
    if [ "$element" == "$i" ]; then
      return 1
    fi
  done
  return 0
}

function display_help () {
    echo ":: Usage: password-manager [action] [options]"
    echo ":: Script available actions: [add get update delete generate]"
    echo ":: Use -f|--file: path to file containing encrypted passwords"
    echo ":: Use -s|--service: name of the service"
    echo ":: Use -h|--help: for help"
    echo ":: Use -V|--version: for info"
    return 0
}

function prompt_missing_info () {
  if [ -z $USERID ]; then
    echo -n "$exc GPG UserID: "
    read -r USERID
  fi

  if [ -z $DATABASE ]; then
    echo -n "$exc Database path: "
    read -r DATABASE
  fi

  if [ "$ACTION" != "list" ]; then
    if [ -z $SERVICE ]; then
      echo -n "$exc Service: "
      read SERVICE
    fi
  fi
}

function parse_args () {
  if [ $# -eq 0 ]; then           # Check if at least one arg was passed
    display_help
    exit 1
  fi


  while (( "$#" )); do
    case $1 in
      -V|--version) 
        echo ":: Author: Giovani Ferreira"
        echo ":: Source: https://github.com/giovanifss/Scripts"
        echo ":: License: GPLv3"
        echo ":: Version: 0.1"
        exit 0;;

      -h|--help)
        display_help
        exit 0;;

      -f|--file)
        if [ -z $2 ] || [[ $2 == -* ]]; then
          echoerr "$mark Expected argument after file option"
          exit 3
        fi
        DATABASE=$2
        shift;;

      -s|--service)
        if [ -z $2 ] || [[ $2 == -* ]]; then
          echoerr "$mark Expected argument after service option"
          exit 3
        fi
        SERVICE=$2
        shift;;

      *)
        if [ ! -z $ACTION ] || [[ $1 == -* ]]; then
          echoerr "$mark Unknown argument '$1'"
          exit 3
        fi

        if not_in "$1" "${ACTIONS[@]}"; then
          echoerr "$mark Unsupported action '$1'"
          echoerr "$mark Use -h or --help to see available actions"
          exit 2
        fi
        ACTION=$1
    esac
    shift
  done

  if [ -z $ACTION ]; then
    echoerr "$mark Action not specified"
    echoerr "$mark Use -h or --help to see available actions"
    exit 3
  fi
}

function clipboard_password () {
  password="$1"
  copied=false

  command -v xsel &>/dev/null &&
    echo -n "$password" | xsel -b &&
    copied=true

  if ! $copied; then
    command -v xclip &>/dev/null &&
      echo -n "$password" | xclip -sel clip &&
      copied=true
  fi

  if $copied; then
    echo "$tick Password copied to clipboard!"
  else
    echo "$mark Unable to copy password to clipboard"
    echo "$exc Password: $password"
  fi

}

function backup_db () {
  dbpath=$1
  newdb=$2

  if [ -f "$dbpath.bkp" ]; then
    cp "$dbpath.bkp" "$dbpath.bkp2"
  fi

  if [ -f "$dbpath.bkp" ]; then
    rm "$dbpath.bkp"
  fi

  mv "$dbpath" "$dbpath.bkp" &&
  mv "$newdb" "$dbpath"

  if [ -f "$dbpath.bkp2" ]; then
    rm "$dbpath.bkp2"
  fi
}

function lock_db () {
  dbpath=$1
  plaintext=$2
  echo "$plaintext" | gpg --sign -r "$USERID" --output "$dbpath" --encrypt
}

function unlock_db () {
  dbpath=$1
  gpg --decrypt "$dbpath" 2>/dev/null
}

function list_services () {
  services=$(unlock_db "$DATABASE" | cut -d ' ' -f1 | cut -d ':' -f1)
  if [ -z "$services" ]; then
    echoerr "$mark Unable to list services"
    exit 8
  fi

  echo "$exc ------ Services in database ----- $exc"
  echo_prefixed "$tick" "${services[@]}"
}

function query_password () {
  service_name="$1"
  PASSWORD=$(unlock_db "$DATABASE" | grep -i "$service_name" | head -n1 | cut -d ' ' -f2)
  if [ -z $PASSWORD ]; then
    echoerr "$mark Password for '$service_name' not found"
    exit 6
  fi
  clipboard_password "$PASSWORD"
}

function delete_password () {
  service_name="$1"
  tmp_dbname="/tmp/.db"

  cp "$DATABASE" "$tmp_dbname"
  db_content=$(unlock_db "$tmp_dbname") &&
    rm "$tmp_dbname"

  lines="$(echo "$db_content" | grep -i "$service_name")"

  prompt_confirmation "$lines" "Lines to delete"
  lock_db "$tmp_dbname" "$(echo "$db_content" | grep -v -i "$service_name")" &&
    unset db_content &&
    backup_db "$DATABASE" "$tmp_dbname" &&
    echo "$tick Password deleted"
}

function update_password () {
  echo "bla"
}

function add_password () {
  service_name="$1"
  password="$2"
  tmp_dbname="/tmp/.db"

  cp "$DATABASE" "$tmp_dbname"
  db_content=$(unlock_db "$tmp_dbname") &&
    rm "$tmp_dbname"

  db_content=$(echo -e "$db_content\n$service_name: $password")
  lock_db "$tmp_dbname" "$db_content" &&
    unset db_content &&
    backup_db "$DATABASE" "$tmp_dbname"
}

function generate_password () {
  echo -n "$exc Number of characters: "
  read -r numchars

  PASSWORD="$(tr -dc 'A-Za-z0-9!"#$%&'\''()*+,-./:;<=>?@[\]^_`{|}~' </dev/urandom | head -c "$numchars"; echo -n)"

  add_password "$SERVICE" "$PASSWORD"
  clipboard_password "$PASSWORD"
}

function main () {
  case $ACTION in
    add)
      echo -n "$exc Password: "
      read -rs PASSWORD
      echo
      add_password "$SERVICE" "$PASSWORD"
      echo "$tick Password added to database";;
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

parse_args "$@"
prompt_missing_info
main
