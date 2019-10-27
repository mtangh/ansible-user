#!/bin/bash
THIS="${BASH_SOURCE##*/}"
CDIR=$([ -n "${BASH_SOURCE%/*}" ] && cd "${BASH_SOURCE%/*}" &>/dev/null; pwd)

# Run tests
echo "[${tests_name}] syntax-check_shells" && {

  check_in=0
  check_ng=0

  for s in *.sh
  do
    check_in=1
    bash -n "${s}" || check_ng=1
  done &&
  [ ${check_in} -ne 0 ] &&
  [ ${check_ng} -eq 0 ]

} &&
echo "[${tests_name}] DONE."

# End
exit $?
