#!/bin/bash
set +e
trap 'exit' INT

# # Keep sudo
# sudo -v
# while true; do
#     sudo -n true
#     sleep 60
#     kill -0 "$$" || exit
# done 2>/dev/null &

DAY=$(date +%Y-%m-%d)
_DAY=$(date +%Y%m%d)
TIME=$(date +%H-%M-%S)
_TIME=$(date +%H%M%S)
TEMPTEMP="${_DAY}${_TIME}"
_ROOT_PATH=$(dirname "$0")
TOOL_PATH=$_ROOT_PATH/tools
TOOLS=$(ls $TOOL_PATH | grep -v '^_' | sort)
INSTALL=()
STACK=()

if test -t 1; then
    tcolors=$(tput colors)
    if test -n "$tcolors" && test $tcolors -ge 8; then
        dim="$(tput dim)"
        bold="$(tput bold)"
        normal="$(tput sgr0)"
        red="$(tput setaf 1)"
        green="$(tput setaf 2)"
        yellow="$(tput setaf 3)"
    fi
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        -D | --debug)
            DEBUG=1
            shift
            ;;
        -l | --list)
            echo "    Available tools:"
            for tool in $TOOLS; do
                description=$(grep '^# Description: ' "${TOOL_PATH}/$tool" |
                    cut -d' ' -f 3-)
                printf "%30s   %s\n" "$tool" "$description"
            done
            exit
            ;;
        -A | --all)
            INSTALL=($TOOLS)
            shift
            ;;
        -r | --restart)
            RESTART_SHELL=1
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
Usage: $(basename $0) [OPTION]... [TOOL]...

Options:
  -A, --all         Install all available tools.
  -D, --debug       Enable debug logging, including command output for each step.
  -h, --help        Display this help text and exit.
  -l, --list        Display all available tools and exit.
  -r, --restart     Restart the shell upon completion.

If no TOOL (and the -A/--all flag is not set), the 'bash' tool will be setup.

EOF
            exit
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

function _run {
    local msg=$1
    shift
    if [ -z "$DEBUG" ]; then
        echo -n "$msg ... "
        "$@" >/dev/null 2>&1
    else
        echo "$msg ... "
        "$@"
    fi
    echo "${green}done.${normal}"
}

function _tool {
    local recipe
    local path
    if [ -f "$1" ]; then
        recipe="$(basename $1)"
        path=$(dirname "$1")
    elif [ -f "${TOOL_PATH}/$1" ]; then
        recipe="$1"
        path="${TOOL_PATH}"
    else
        echo "${bold}${red}Could not load tool '$1'${normal}" >&2
        exit 1
    fi
    STACK+=("$1")
    pushd "$path" >/dev/null
    echo "${dim}-- Tool [${STACK[@]}]${normal}"
    source "./${recipe}"
    popd >/dev/null
    unset 'STACK[${#STACK[@]}-1]'
    echo "${dim}-- Tool [${STACK[@]}]${normal}"

}

USER=${USER:-$(whoami)}
_PLATFORM=$(uname -s | awk '{print tolower($1)}')

case $_PLATFORM in
    linux)
        if [ -f /etc/arch-release ]; then
            _PLATFORM=arch
        elif [ -f /etc/debian_version ]; then
            _PLATFORM=debian
        fi
        ;;
esac

if [ "${#INSTALL[@]}" -eq 0 ]; then
    INSTALL=(bash)
fi

for tool in "${INSTALL[@]}"; do
    _tool $tool
done

echo "${green}Finished${normal}"
if [ -n "$RESTART_SHELL" ]; then
    echo "Restarting shell."
    exec $SHELL
fi
