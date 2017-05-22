#!/bin/bash
THIS="${0##*/}"
CDIR=$([ -n "${0%/*}" ] && cd "${0%/*}" 2>/dev/null; pwd)

# Name
THIS="${THIS:-ansible-user}"
BASE="${THIS%%.*}"

# Environment Variables
ANSIBLE_USER_SSH_HOST="${ANSIBLE_USER_SSH_HOST:-}"
ANSIBLE_USER_USERNAME="${ANSIBLE_USER_USERNAME:-}"
ANSIBLE_USER_KEY_FILE="${ANSIBLE_USER_KEY_FILE:-}"
ANSIBLE_USER_DEBUGRUN="${ANSIBLE_USER_DEBUGRUN:-}"

# Shell script local Variables
_au_exec_cmd=""
_au_play_cmd="$(type -P ansible-playbook)"
_au_playopts=""
_au_tmphosts="/tmp/.${BASE}-hosts-"$(mktemp -u XXXXXXXXXXXX)".txt"

# Check the command
[ -x "$_au_play_cmd" ] || {
  echo "$THIS: ERROR: 'ansible-playbook' not found." 1>&2
  exit 1
}

# Check the playbook
[ -r "${CDIR}/${BASE}.yml" ] || {
  echo "$THIS: ERROR: '${BASE}.yml' not found." 1>&2
  exit 2
}

# Function: _usage
_usage() {
  cat <<_USAGE_
Usage: $THIS init [OPTIONS]
       $THIS create [OPTIONS]
       $THIS update [OPTIONS]

"init" Options:
  --force
    rebuild ssh key

"create" and "update" Options:
  -i HOSTFILE, --inventory=HOSTFILE
      use thia file to inventory
  -h HOSTNAME[:PORT], --host=HOSTNAME[:PORT]
      remote server hostname or ip address (and port)
  -u REMOTE_USER, --user=REMOTE_USER
      connect as this user (default=$USER)
  -T TIMEOUT
      override the connection timeout in seconds (default=10)
  --key-file=PRIVATE_KEY_FILE
      use this file to authenticate the connection

_USAGE_
  exit 0
}

# Function: _cleanup
_cleanup() {
  [ -z "${ANSIBLE_USER_DEBUGRUN}" ] || {
    echo rm -f "${_au_tmphosts}"
  }
  [ -z "${ANSIBLE_USER_DEBUGRUN}" ] && {
    [ -e "${_au_tmphosts}" ] &&
    rm -f "${_au_tmphosts}"
  } 1>/dev/null 2>&1
  return 0
}

# Function: inti
_au_init() {
  local _au_keyrenew=""
  # Parse options
  while [ $# -gt 0 ]
  do
    case "$1" in
    --force)
      _au_keyrenew="yes"
      ;;
    *)
      ;;
    esac
    shift
  done
  # Crate a inventory
  echo "localhost" >"${_au_tmphosts}"
  # Options
  _au_playopts=""
  _au_playopts="${_au_playopts:+$_au_playopts }-i $_au_tmphosts"
  _au_playopts="${_au_playopts:+$_au_playopts }-c local --flush-cache"
  _au_playopts="${_au_playopts:+$_au_playopts }-t ${BASE}-ssh-keygen"
  _au_playopts="${_au_playopts:+$_au_playopts }-e am_user_using_become=no"
  _au_playopts="${_au_playopts:+$_au_playopts }-e am_user_using_gather_facts=no"
  _au_playopts="${_au_playopts:+$_au_playopts }-e am_user_sshkey_renew=${_au_keyrenew:-}"
  _au_playopts="${_au_playopts:+$_au_playopts }${ANSIBLE_USER_DEBUGRUN:+-C -vvvv}"
  # end
  return 0
}

# Function: create
_au_create() {
  local _au_hostfile="${ANSIBLE_USER_HOSTFILE}"
  local _au_hostname="${ANSIBLE_USER_SSH_HOST}"
  local _au_login_id="${ANSIBLE_USER_USERNAME:-$USER}"
  local _au_pkeyfile="${ANSIBLE_USER_KEY_FILE}"
  local _au_connmode=""
  local _au_time_out=""
  # Parse options
  while [ $# -gt 0 ]
  do
    case "$1" in
    -i*|--inventory*)
      if [[ $1 =~ ^-i ]] && [ -n "${1#*-i}" ]
      then _au_hostfile="${1#*-h}"
      elif [[ $1 =~ ^--inventory= ]] && [ -n "${1#*=}" ]
      then _au_hostfile="${1#*=}"
      else _au_hostfile="${2}"; shift
      fi
      ;;    
    -h*|--host*)
      if [[ $1 =~ ^-h ]] && [ -n "${1#*-h}" ]
      then _au_hostname="${_au_hostname:+$_au_hostname }${1#*-h}"
      elif [[ $1 =~ ^--host= ]] && [ -n "${1#*=}" ]
      then _au_hostname="${_au_hostname:+$_au_hostname }${1#*=}"
      else _au_hostname="${_au_hostname:+$_au_hostname }${2}"; shift
      fi
      ;;
    -u*|--user*)
      if [[ $1 =~ ^-u ]] && [ -n "${1#*-u}" ]
      then _au_login_id="${1#*-u}"
      elif [[ $1 =~ ^--user= ]] && [ -n "${1#*=}" ]
      then _au_login_id="${1#*=}"
      else _au_login_id="${2}"; shift
      fi
      ;;
    --key-file*)
      if [[ $1 =~ ^--key-file= ]] && [ -n "${1#*=}" ]
      then _au_pkeyfile="${1#*=}"
      else _au_pkeyfile="${2}"; shift
      fi
      ;;
    -T*)
      if [ -n "${1#*-T}" ]
      then _au_time_out="${1#*-T}"
      else _au_time_out="${2}"; shift
      fi
      ;;
    --auto)
      _au_connmode=""
      ;;
    --ssh)
      _au_connmode="ssh"
      ;;
    --local)
      _au_connmode="local"
      ;;
    *)
      ;;
    esac
    shift
  done
  # Parameter validation
  [ -n "${_au_hostfile}" -o -n "${_au_hostname}" ] || {
    echo "$THIS: ERROR: You must specify HOSTFILE or HOSTNAME." 1>&2
    exit 1
  }
  [ -z "${_au_hostfile}" ] ||
  [ -r "${_au_hostfile}" ] || {
    echo "$THIS: ERROR: Can not read a '${_au_hostfile}' file." 1>&2
    exit 2
  }
  # Crate a inventory
  [ -n "${_au_hostfile}" ] || {
    cat /dev/null 1>"${_au_tmphosts}" && {
      echo "${_au_hostname}" |tr ',' ' ' |
      while read _au_host_ent
      do
        [ -z "${_au_host_ent}" ] ||
        echo "${_au_host_ent}"
      done |sort -u 1>>"${_au_tmphosts}" 
      unset _au_host_ent
    } 2>/dev/null || {
      echo "$THIS: ERROR: '${_au_tmphosts}': Permission denied." 1>&2
      exit 3
    }
  }
  # Options
  _au_playopts=""
  _au_playopts="${_au_playopts:+$_au_playopts }-i $_au_tmphosts"
  _au_playopts="${_au_playopts:+$_au_playopts }${_au_connmode:+-c $_au_connmode}"
  _au_playopts="${_au_playopts:+$_au_playopts }${_au_login_id:+-u $_au_login_id}"
  _au_playopts="${_au_playopts:+$_au_playopts }${_au_time_out:+-T $_au_time_out}"
  if [ -z "${ANSIBLE_USER_DEBUGRUN}" ]
  then
    if [ -z "${_au_pkeyfile}" ]
    then
      _au_playopts="${_au_playopts:+$_au_playopts }--key-file=${_au_pkeyfile}"
    else
      _au_playopts="${_au_playopts:+$_au_playopts }-k"
    fi
    _au_playopts="${_au_playopts:+$_au_playopts }-b -K"
    _au_playopts="${_au_playopts:+$_au_playopts }-e am_user_using_become=yes"
    _au_playopts="${_au_playopts:+$_au_playopts }-e am_user_using_gather_facts=yes"
  else
    _au_playopts="${_au_playopts:+$_au_playopts }-e am_user_using_become=no"
    _au_playopts="${_au_playopts:+$_au_playopts }-e am_user_using_gather_facts=no"
    _au_playopts="${_au_playopts:+$_au_playopts }-C -vvv"
  fi
  # end
  return 0
}

# Function: update
_au_update() {
  _au_create "$@"
  # Options
  _au_playopts="${_au_playopts:+$_au_playopts }$-t ${BASE}-authorized-keys"
  _au_playopts="${_au_playopts:+$_au_playopts }$-t ${BASE}-sudoers"
  # end
  return 0
}

# Trap
trap _cleanup SIGTERM SIGHUP SIGINT SIGQUIT
trap _cleanup EXIT

# RC
[ -r "${CDIR}/${BASE}.rc" ] && {
 . "${CDIR}/${BASE}.rc"
} 1>/dev/null 2>&1 || :

# Command
_au_exec_cmd="${1}"; shift

# Shell Options
set -u

# Exec command
case "$_au_exec_cmd" in
init|create|update)
  _au_${_au_exec_cmd} "$@"
  ;;
*)
  _usage
  ;;
esac

# debug
[ -z "${ANSIBLE_USER_DEBUGRUN}" ] || {
  echo $_au_play_cmd $_au_playopts "${CDIR}/${BASE}.yml"
}

# play
$_au_play_cmd $_au_playopts "${CDIR}/${BASE}.yml"

# end
exit $?
# vim: set ff=unix ts=2 sw=2 sts=2 et : This line is VIM modeline
