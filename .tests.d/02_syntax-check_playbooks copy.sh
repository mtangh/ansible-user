#!/bin/bash
THIS="${BASH_SOURCE##*/}"
CDIR=$([ -n "${BASH_SOURCE%/*}" ] && cd "${BASH_SOURCE%/*}" &>/dev/null; pwd)

# Run tests
echo "[${tests_name}] syntax-check_playbooks" && {

  ansible-playbook ansible-user.yml --syntax-check

} &&
echo "[${tests_name}] DONE."

# End
exit $?
