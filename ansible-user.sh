#!/bin/bash
THIS="${0##*/}"
CDIR=$([ -n "${0%/*}" ] && cd "${0%/*}" 2>/dev/null; pwd)

# Name
THIS="${THIS:-ansible-user}"
BASE="${THIS%%.*}"

# Internal Variables
_au_exec_cmd=""
_au_play_cmd=""
_au_playopts=""
_au_work_dir="${CDIR}/work"
_au_tmphosts=$(mktemp -u /tmp/.${BASE}-hosts-XXXXXXXX.txt)

# Function: _usage
_usage() {
  cat <<_USAGE_
Usage: $THIS {init|create|update} [OPTIONS]

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
  local _au_forceflg=0
  # Parse options
  while [ $# -gt 0 ]
  do
    case "$1" in
    --force)
      _au_forceflg=1
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
  _au_playopts="${_au_playopts} -i '$_au_tmphosts'"
  _au_playopts="${_au_playopts} -c local"
  _au_playopts="${_au_playopts} -t '${BASE}-ssh-keygen'"
  [ $_au_forceflg -eq 0 ] ||
  _au_playopts="${_au_playopts} -e ansible_user_sshkey_renew=yes"
  # end
  return 0
}

# Function: create
_au_create() {
  local _au_login_id=""
  # Parse options
  while [ $# -gt 0 ]
  do
    case "$1" in
    --user)
      _au_login_id="$2"
      shift
      ;;
    --force)
      _au_forceflg=1
      ;;
    *)
      ;;
    esac
    shift
  done
  # Options
  _au_playopts=""
  _au_playopts="${_au_playopts} -i '$_au_tmphosts'"
  _au_playopts="${_au_playopts} -c local"
  _au_playopts="${_au_playopts} -t '${BASE}-ssh-keygen'"
  [ $_au_forceflg -eq 0 ] ||
  _au_playopts="${_au_playopts} -e ansible_user_sshkey_renew=yes"
  # end
  return 0
}

# Function: update
_au_update() {
}

# Trap
trap _cleanup SIGTERM SIGHUP SIGINT SIGQUIT
trap _cleanup EXIT

# RC
[ -r "${CDIR}/${BASE}.rc" ] && {
 . "${CDIR}/${BASE}.rc"
} 1>/dev/null 2>&1 || :

# Shell Options
set -u

# Create a workdir if not exists
[ -d "${_au_work_dir}" ] || {
  mkdir -p "${_au_work_dir}"
}

# Command
_au_exec_cmd="$1"; shift

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
