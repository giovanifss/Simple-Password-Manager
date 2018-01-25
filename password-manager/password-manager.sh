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
USERID=""
#
# Set here the location of your 'database':
DATABASE=""
#-------------------------------------------------------------------

ACTIONS=(add get update delete generate) # Script actions
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

  if [ -z $SERVICE ]; then
    echo -n "$exc Service: "
    read SERVICE
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
  plaintext_path=$2
  gpg --sign -r "$USERID" --output "$dbpath" --encrypt "$plaintext_path" &>/dev/null &&
    rm "$plaintext_path"
}

function unlock_db () {
  dbpath=$1
  plaintext_path=$2
  gpg --output "$plaintext_path" --decrypt "$dbpath" &>/dev/null
}

function query_password () {
  service_name="$1"
  PASSWORD=$(gpg -d "$DATABASE" 2>/dev/null | grep -i "$service_name" | cut -d ' ' -f2)
  if [ -z $PASSWORD ]; then
    echoerr "$mark Password for '$service_name' not found"
    exit 6
  fi
  clipboard_password "$PASSWORD"
}

function delete_password () {
  service_name="$1"
  tmp_dbname="/tmp/.db"
  tmp_plaintext="/tmp/.plaintext"
  tmp_deleted="/tmp/.deleted"

  cp "$DATABASE" "$tmp_dbname" &&
    unlock_db "$tmp_dbname" "$tmp_plaintext" &&
    rm "$tmp_dbname"

  lines="$(grep -i "$service_name" "$tmp_plaintext")"

  prompt_confirmation "$lines" "Lines to delete" &&
    grep -v -i "$service_name" "$tmp_plaintext" > "$tmp_deleted" &&
    rm "$tmp_plaintext" &&
    mv "$tmp_deleted" "$tmp_plaintext" &&
    lock_db "$tmp_dbname" "$tmp_plaintext" &&
    backup_db "$DATABASE" "$tmp_dbname" &&
    echo "$tick Password deleted" || rm "$tmp_plaintext"
}

function update_password () {
  echo "bla"
}

function add_password () {
  service_name="$1"
  password="$2"
  tmp_dbname="/tmp/.db"
  tmp_plaintxt="/tmp/.plaintext"

  cp "$DATABASE" "$tmp_dbname" &&
    unlock_db "$tmp_dbname" "$tmp_plaintxt" &&
    rm "$tmp_dbname" &&
    echo "$service_name: $password" >> "$tmp_plaintxt" &&
    lock_db "$tmp_dbname" "$tmp_plaintxt" &&
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
