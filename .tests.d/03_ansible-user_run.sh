#!/bin/bash
THIS="${BASH_SOURCE##*/}"
CDIR=$([ -n "${BASH_SOURCE%/*}" ] && cd "${BASH_SOURCE%/*}" &>/dev/null; pwd)

# Run tests
echo "[${tests_name}] syntax-check_playbooks" && {

  : "Create an authorized keys" && {

    bash ansible-user.sh init &&
    [ -r "${HOME}/.ssh/ansible-id_rsa" -a \
      -r "${HOME}/.ssh/ansible-id_rsa.pub" ]

  } &&
  : "Create a user" && {

    export ANSIBLE_USER_DEBUGRUN=yes &&
    bash ansible-user.sh create -h localhost --local

  }

} &&
echo "[${tests_name}] DONE."

# End
exit $?
