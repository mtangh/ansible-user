#!/bin/bash
THIS="${0##*/}"
CDIR=$([ -n "${0%/*}" ] && cd "${0%/*}" 2>/dev/null; pwd)

# Name
THIS="${THIS:-.travis.yml}"
BASE="${THIS%.*}"

# Ansible playbook
play=$(type -P ansible-playbook)

# Errors
errs=0

# Run test func.
test_syntaxcheck_after_run() {
  local test="$1"
  local host=""
  local rval=1

  [ -e "${test}" ]     || return 120
  [ -d "${test%/*}" ]  || return 121
  [ -n "${test##*/}" ] || return 122
  pushd "${test%/*}"   || return 123

  for file in inventory hosts
  do 
    [ ! -e "$file" ] || {
    host="$file"; break; }
  done || :

  $play ${host:+-i $host} "${test##*/}" --syntax-check &&
  $play ${host:+-i $host} "${test##*/}" -C; rval=$?

  [ $rval -eq 0 ]  &&
  for test_casename in $(
    $play ${host:+-i $host} "${test##*/}" --list-tags 2>/dev/null |
    sed -ne 's/^[ ]*play.*[ ]*TAGS:[ ]*\[\([^ ]*\)\].*$/\1/gp' |
    sort -u)
  do
    $play ${host:+-i $host} "${test##*/}" \
          --tags "$test_casename" \
          -e "test_casename=$test_casename"
    rval=$?
    [ $rval -eq 0 ] ||
    break
  done

  popd || :

  return $rval
}

# Setup
ansible -m setup localhost || :

# OS spec
test_syntaxcheck_after_run \
"${CDIR}/platforms/tests/test.yml" ||
exit 1

# Run tests
for test in \
$(find "${CDIR}" -maxdepth 3 -type f -a -name "test.yml" 2>/dev/null)
do
  
  echo "${test}" |
  grep "/platforms/tests/" 1>/dev/null 2>&1 &&
  continue

  test_syntaxcheck_after_run "${test}" ||
  errs=$((errs + 1))

done

# End
exit $errs
