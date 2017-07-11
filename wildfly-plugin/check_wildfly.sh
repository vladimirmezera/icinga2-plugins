#!/bin/sh
#
#
# A simple "Wildfly check" to be used for monitoring thread and jvm
#

me="$(basename $0)"

usage () {
cat <<EOF
Usage: $me [options]
A short description of what this check does should be here,
but it is not (yet). If server run in 'standalone' mode don't setup parameters 's' and 'c'. 
Options:
  -a Address of endpoint e.g. http://localhost:9990/management
  -u User for authentication 
  -p Password for authentication
  -s Server in domain mode
  -c Host controller in domain mode
  --help, -h     Print this help text.
EOF
}


## exit statuses recognized by Nagios
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3


## helper functions
die () {
  rc="$1"
  shift
  (echo -n "ERROR: ";
      if [ $# -gt 0 ]; then echo "$@"; else cat; fi) 1>&2
  exit $rc
}

warn () {
  (echo -n "WARNING: ";
      if [ $# -gt 0 ]; then echo "$@"; else cat; fi) 1>&2
}

have_command () {
  type "$1" >/dev/null 2>/dev/null
}

require_command () {
  if ! have_command "$1"; then
    die 1 "Could not find required command '$1' in system PATH. Aborting."
  fi
}

is_error_http_state () {
  if [[ "$1" =~ [4-5][0-9][0-9] ]]; then
    die 1 "Error response $1"		
  fi
}

is_absolute_path () {
    expr match "$1" '/' >/dev/null 2>/dev/null
}


## parse command-line

short_opts='a:u:p:s:c:hm:'
long_opts='help'

# test which `getopt` version is available:
# - GNU `getopt` will generate no output and exit with status 4
# - POSIX `getopt` will output `--` and exit with status 0
getopt -T > /dev/null
rc=$?
if [ "$rc" -eq 4 ]; then
    # GNU getopt
    args=$(getopt --name "$me" --shell sh -l "$long_opts" -o "$short_opts" -- "$@")
    if [ $? -ne 0 ]; then
        die 1 "Type '$me --help' to get usage information."
    fi
    # use 'eval' to remove getopt quoting
    eval set -- $args
else
    # old-style getopt, use compatibility syntax
    args=$(getopt "$short_opts" "$@")
    if [ $? -ne 0 ]; then
        die 1 "Type '$me --help' to get usage information."
    fi
    set -- $args
fi

while [ $# -gt 0 ]; do
    case "$1" in
	-a) url="$2"; shift;;
	-u) user="$2"; shift;;
	-p) password="$2"; shift;;
	-s) server="$2"; shift;;
	-c) controller=$2; shift;;
        --help|-h)    usage; exit 0 ;;
        --)           shift; break ;;
    esac
    shift
done


## main

# RETURN OUTPUT TO NAGIOS
# using the example `-m` parameter parsed from commandline

#Test jq command 
require_command jq

prefix=""
if [ ! -z $server ] && [ ! -z $controller ];then
  prefix="/host/$controller/server/$server"
fi	

raw_content=$(curl -s --digest -u $user:$password -w "\n%{http_code}" -X GET "$url/management$prefix/core-service/platform-mbean/type/memory/?include-runtime=true")
content="${raw_content%$'\n'*}"
http_status="${raw_content##*$'\n'}"

init=$(echo $content | jq '.["heap-memory-usage"].init')
used=$(echo $content | jq '.["heap-memory-usage"].used')
commited=$(echo $content | jq '.["heap-memory-usage"].committed')
max=$(echo $content | jq '.["heap-memory-usage"].max')

is_error_http_state $http_status 

raw_content_thread=$(curl -s --digest -u $user:$password -w "\n%{http_code}" -X GET "$url/management$prefix/core-service/platform-mbean/type/threading/?include-runtime=true")
content_thread="${raw_content_thread%$'\n'*}"
http_status="${raw_content_thread##*$'\n'}"


used_thread=$(echo $content_thread | jq '.["thread-count"]')
peak_thread=$(echo $content_thread | jq '.["peak-thread-count"]')
create_thread=$(echo $content_thread | jq '.["total-started-thread-count"]')

message="HEAP parameters: init=$init, used=$used, committed=$commited, max=$max Thread parameters: used=$used_thread, peak=$peak_thread, total=$create_thread"

echo "OK - ${message} | usedjvm=$used usedthread=$used_thread"
exit $OK
