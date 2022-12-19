#!/usr/bin/env bash
RES1=$(date +%s.%N)

set +e
trap cleanup SIGTERM ERR EXIT
trap "echo ------ [The script is terminated] ------^C; exit_with_error" SIGINT

DAY=$(date +%Y-%m-%d)
TIME=$(date +%H-%M-%S)

_DAY=$(date +%Y%m%d)
_TIME=$(date +%H%M%S)
TEMP_TEMP=${_DAY}${_TIME}
ISOF=$(date --iso-8601=seconds)

PATH_ROOT=$(dirname "$0")
PATH_TOOL=$PATH_ROOT/tools
tools=$(ls $PATH_TOOL | grep -v '^_' | sort)
INSTALL=()
STACK=()

function setup_colors {
    if test -t 1 && [[ -z "${NO_COLOR-}" ]]; then
        tcolors=$(tput colors)
        if test -n "$tcolors" && test $tcolors -ge 8; then
            DIM="$(tput dim)"
            BOLD="$(tput bold)"
            NORMAL="$(tput sgr0)"
            RED="$(tput setaf 1)"
            GREEN="$(tput setaf 2)"
            YELLOW="$(tput setaf 3)"
            BLUE="$(tput setaf 4)"
            MAGENTA="$(tput setaf 125)"
            CYAN="$(tput setaf 6)"
        fi
    fi
}

function exit_with_error {
    local duration=$(echo "$(date +%s.%N) - $RES1" | bc)
    local execution_time=$(printf "%.4f Seconds <<<" $duration)
    echo ">>> [${RED}Incomplete Process${NORMAL}]: $execution_time"
    exit 1
}

function msg {
    echo >&2 -e "${1-}"
}

function cleanup {
    trap - SIGINT SIGTERM ERR EXIT
    # TRASH=$(mktemp -t tmp.XXXXXXXXXX)
    # echo "Removing temporary files: $TRASH"
    # rm -rf "$TRASH"
    # exit_with_error
}

function die {
    local msg=$1
    local code=${2-1}
    msg "$msg"
    # exit "$code"
    exit_with_error
}

function _run {
    local msgl=$1
    shift
    if [ -z "$DEBUG" ]; then
        echo -n "$msgl ${BLUE}-->${NORMAL} "
        "$@" >/dev/null 2>&1
    else
        echo "$msgl"
        "$@"
    fi
    echo "${GREEN}Done${NORMAL}"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -D | --debug)
            DEBUG=1
            shift
            ;;
        -v | --verbose)
            set -x
            shift
            ;;
        -l | --list)
            printf "%-45s %s %s\n" "-----Description-----" "-----Tools-----"
            for tool in $tools; do
                description=$(grep '^# Description: ' "${PATH_TOOL}/$tool" | cut -d' ' -f 3-)
                argument=$(grep '^# Arguments: ' "${PATH_TOOL}/$tool" | cut -d' ' -f 3-)
                printf "%-45s %s %s\n" "$description" "$tool" "$argument"
            done
            exit_with_error
            ;;
        -A | --all)
            INSTALL=($tools)
            shift
            ;;
        -r | --restart)
            RESTART_SHELL=1
            shift
            ;;
        --no-color)
            NO_COLOR=1
            shift
            ;;
        --domain=*)
            cP_DOMAIN="${1#*=}"
            shift
            ;;
        --email=*)
            cP_EMAIL="${1#*=}"
            shift
            ;;
        -h | --help)
            cat <<EOF
Usage: $(basename $0) [option] [tool]

Options:
  -A, --all         Install all available tools.
  -D, --debug       Enable debug logging, including command output for each step.
  -v, --verbose     Enable verbose mode.
  -h, --help        Display this help text and exit.
  -l, --list        Display all available tools and exit.
  -r, --restart     Restart the shell upon completion.
  --no-color        Disable color

If no [tool] (and the -A/--all flag is not set), the 'demo' tool will be setup.

EOF
            exit_with_error
            ;;
        *)
            INSTALL+=("$1")
            shift
            ;;
    esac
done

INSTALL=($(for tool in "${INSTALL[@]}"; do
    echo $tool
done | sort | uniq))

setup_colors

function _tool {
    local tool
    local path
    if [ -f "$1" ]; then
        tool="$(basename $1)"
        path=$(dirname "$1")
    elif [ -f "${PATH_TOOL}/$1" ]; then
        tool="$1"
        path="${PATH_TOOL}"
    else
        msg "-- Tool [${BOLD}${BLUE}$1${NORMAL}] ${RED}does not exist${NORMAL}." >&2
        exit_with_error
    fi
    STACK+=("$1")
    pushd "$path" >/dev/null
    msg "${DIM}-- Tool [${STACK[@]}]${NORMAL}"
    source "./${tool}"
    popd >/dev/null
    unset 'STACK[${#STACK[@]}-1]'

}

if [ "${#INSTALL[@]}" -eq 0 ]; then
    INSTALL=(demo)
fi

for tool in "${INSTALL[@]}"; do
    _tool $tool
done

if [ -n "$RESTART_SHELL" ]; then
    echo "-- Restarting Shell --"
    exec $SHELL
fi

# end time & calculate
RES2=$(date +%s.%N)
dt=$(echo "$RES2 - $RES1" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

printf ">>> [${CYAN}Process Completed${NORMAL}] - [%d Days, %02d Hours, %02d Minutes, %02.4f Seconds] <<<\n" $dd $dh $dm $ds
