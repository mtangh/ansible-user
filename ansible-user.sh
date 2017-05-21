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

# Shell script local Variables
_au_exec_cmd=""
_au_play_cmd="$(type -P ansible-playbook)"
_au_playopts=""
_au_work_dir="${CDIR}/work"
_au_tmphosts="/tmp/.${BASE}-hosts-"$(mktemp -u XXXXXXXXXXXX)".txt"

# Check command
[ -x "$_au_play_cmd" ] || {
  echo "$THIS: ERROR: 'ansible-playbook' not found." 1>&2
  exit 1
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
 : && {
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
  _au_playopts="${_au_playopts:+$_au_playopts }-e ansible_user_using_become=no"
  _au_playopts="${_au_playopts:+$_au_playopts }-e ansible_user_using_gather_facts=no"
  _au_playopts="${_au_playopts:+$_au_playopts }-e ansible_user_sshkey_renew=${_au_keyrenew:-}"
  # end
  return 0
}

# Function: create
_au_create() {
  local _au_hostname="${ANSIBLE_USER_SSH_HOST}"
  local _au_login_id="${ANSIBLE_USER_USERNAME:-$USER}"
  local _au_pkeyfile="${ANSIBLE_USER_KEY_FILE}"
  local _au_connmode=""
  local _au_time_out=""
  # Parse options
  while [ $# -gt 0 ]
  do
    case "$1" in
    -h*|--host*)
      if [[ $1 =~ ^-h ]] && [ -n "${1#*-h}" ]
      then _au_hostname="${1#*-h}"
      elif [[ $1 =~ ^--host= ]] && [ -n "${1#*=}" ]
      then _au_hostname="${1#*=}"
      else _au_hostname="${2}"; shift
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
  [ -n "${_au_hostname}" ] || {
    echo "$THIS: ERROR: You must specify a HOSTNAME."
    exit 1
  }
  # Crate a inventory
  echo "${_au_hostname}" >"${_au_tmphosts}"
  # Options
  _au_playopts=""
  _au_playopts="${_au_playopts:+$_au_playopts }-i $_au_tmphosts"
  _au_playopts="${_au_playopts:+$_au_playopts }${_au_connmode:+-c $_au_connmode}"
  _au_playopts="${_au_playopts:+$_au_playopts }${_au_login_id:+-K -b -u $_au_login_id}"
  _au_playopts="${_au_playopts:+$_au_playopts }${_au_pkeyfile:+--key-file=$_au_pkeyfile}"
  _au_playopts="${_au_playopts:+$_au_playopts }${_au_pkeyfile:--k}"
  _au_playopts="${_au_playopts:+$_au_playopts }${_au_time_out:+-T $_au_time_out}"
  _au_playopts="${_au_playopts:+$_au_playopts }-e ansible_user_using_become=yes"
  _au_playopts="${_au_playopts:+$_au_playopts }-e ansible_user_using_gather_facts=yes"
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

# Create a workdir if not exists
[ -d "${_au_work_dir}" ] || {
  mkdir -p "${_au_work_dir}"
}

# Exec command
case "$_au_exec_cmd" in
init|create|update)
  _au_${_au_exec_cmd} "$@"
  ;;
*)
  _usage
  ;;
esac

# play
$_au_play_cmd $_au_playopts "${CDIR}/${BASE}.yml"

# end
exit $?
# vim: set ff=unix ts=2 sw=2 sts=2 et : This line is VIM modeline