#!/bin/bash
RES1=$(date +%s.%N)

set +e
trap cleanup SIGTERM ERR EXIT
trap "echo ------ [The script is terminated] ------C^; exit_with_error" SIGINT

PATH_ROOT=$(dirname "$0")
PATH_TOOL=${PATH_ROOT}/tools
TOOLS=$(ls ${PATH_TOOL} | grep -v '^_' | sort)
SETUP=()
STACK=()

FISO=$(date --iso-8601=seconds)
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H-%M-%S)
_DATE=$(date +%Y%m%d)
_TIME=$(date +%H%M%S)
FDAY=${_DATE}${_TIME}

# TRASH=$(mktemp -t tmp.XXXXXXXXXX)
function cleanup {
    trap - SIGINT SIGTERM ERR EXIT
    # echo "Removing temporary files: $TRASH"
    # rm -rf "$TRASH"
    # exit_with_error
}

function setup_colors {
    if [[ -z "$NO_COLOR" ]]; then
        source ${PATH_ROOT}/color.sh
    fi
}

function exit_with_error {
    local duration=$(echo "$(date +%s.%N) - $RES1" | bc)
    local execution_time=$(printf "%.4f Seconds <<<" $duration)
    _msg ">>> [${Red}Incomplete Process${Normal}]: $execution_time"
    exit 1
}

function _msg {
    echo >&2 -e "${1-}"
}

function _die {
    local msg=$1
    local code=${2-1}
    _msg "$msg"
    # exit "$code"
    exit_with_error
}

function _run {
    local msg=$1
    shift
    if [ -z "$DEBUG" ]; then
        printf "$msg ${Blue}-->${Normal} "
        "$@" >/dev/null 2>&1
    else
        printf "$msg ${Blue}-->${Normal} "
        "$@"
    fi
    printf "${Color01}Done${Normal}\n"
}

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
        # echo -e "-- Tool [${Bold}${Blue}$1${Normal}] ${Red}does not exist${Normal}." >&2
        exit_with_error
    fi
    STACK+=("$1")
    pushd "$path" >/dev/null
    # echo -e "${Dim}-- Tool [${STACK[@]}]${Normal}"
    source "./${tool}"
    popd >/dev/null
    unset 'STACK[${#STACK[@]}-1]'
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -d | --debug)
            DEBUG=1
            shift
            ;;
        -v | --verbose)
            set -x
            shift
            ;;
        -l | --list)
            printf "%-45s %s %s\n" "-----Description-----" "-----Tools-----"
            for tool in ${TOOLS}; do
                description=$(grep '^# Description: ' "${PATH_TOOL}/$tool" | cut -d' ' -f 3-)
                argument=$(grep '^# Arguments: ' "${PATH_TOOL}/$tool" | cut -d' ' -f 3-)
                printf "%-45s %s %s\n" "$description" "$tool" "$argument"
            done
            exit_with_error
            ;;
        -A | --all)
            SETUP=(${TOOLS})
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
            DOMAIN="${1#*=}"
            shift
            ;;
        --email=*)
            EMAIL="${1#*=}"
            shift
            ;;
        -h | --help)
            cat <<EOF
Usage: $(basename $0) [option] [tool]

Options:
  -A, --all         Install all available tools.
  -d, --debug       Enable debug logging, including command output for each step.
  -v, --verbose     Enable verbose mode.
  -h, --help        Display this help text and exit.
  -l, --list        Display all available tools and exit.
  -r, --restart     Restart the shell upon completion.
  --no-color        Disable color output.

If no [tool] (and the -A/--all flag is not set), the 'demo' tool will be setup.

EOF
            exit_with_error
            ;;
        *)
            SETUP+=("$1")
            shift
            ;;
    esac
done

SETUP=($(for tool in "${SETUP[@]}"; do
    echo $tool
done | sort | uniq))

setup_colors

if [ "${#SETUP[@]}" -eq 0 ]; then
    SETUP=(demo)
fi

for tool in "${SETUP[@]}"; do
    _tool $tool
done

if [ -n "$RESTART_SHELL" ]; then
    echo "-- Restarting Shell --"
    exec $SHELL
fi

# ---------------------------------------------------------------------
RES2=$(date +%s.%N)
dt=$(echo "$RES2 - $RES1" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

printf ">>> [${Cyan}Process Completed${Normal}] - [%d Days, %02d Hours, %02d Minutes, %02.4f Seconds] <<<\n" $dd $dh $dm $ds
