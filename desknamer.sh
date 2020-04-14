#!/usr/bin/env bash

# this program automatically renames *existing* desktops according to
# what's running inside. If you wish to add more desktops to a certain monitor,
# you must run 'bspc monitor -d 1 2 3 4 5...' on that monitor to give it
# the desired number of desktops.

BLUE='\e[34m'
GREEN='\e[32m'
RED='\e[31m'
R='\e[0m'

searchApplications() {
	found="$(find -L /usr/share/applications /usr/local/share/applications ~/.local/share/applications -iname "$1".desktop 2>/dev/null | head -1)"
	[ "$found" = "" ] && found="$(find -L /usr/share/applications /usr/local/share/applications ~/.local/share/applications -iname *"$1".desktop 2>/dev/null | head -1)"
	[ "$found" = "" ] && found="$(find -L /usr/share/applications /usr/local/share/applications ~/.local/share/applications -iname *"$1"*.desktop 2>/dev/null | head -1)"
	echo "$found"
}

getAllApplications() {
	local found="$(find -L /usr/share/applications /usr/local/share/applications ~/.local/share/applications -iname *.desktop 2>/dev/null)"
	for application in $found; do
		echo "$application"
	done
}

getCategory() {
	local application="$1"
	if [[ $application =~ '/' ]]; then
		menuItem="$application"
	else
		menuItem="$(searchApplications "$application")"
	fi
	if [ "$menuItem" != "" ]; then
		categories="$(grep -P '^Categories=' "$menuItem" | cut -d '=' -f 2)"
		echo "$categories"
	fi
}

getCategories() {
	local pid="$1"

	local comm="$(cat "/proc/$pid/comm" 2>/dev/null | tr '\0' '\n')"
	[ "${#comm}" -eq 0 ] && return

	local children="$(ps --no-headers --ppid "$pid" 2>/dev/null | awk '{print $1}')"

	getCategory "$comm"
	((recursive)) && for childPid in $children; do
		local childComm="$(cat "/proc/$childPid/comm" 2>/dev/null | tr '\0' '\n')"
		[ "${#childComm}" -gt 0 ] && getCategory "$childComm"
		getCategories "$childPid"
	done
}

getAllCategories() {
	grep -P '^Categories=' $(find -L /usr/share/applications /usr/local/share/applications ~/.local/share/applications -iname *.desktop 2>/dev/null) | cut -d '=' -f 2 | tr ';' '\n' | sort -u
}

getDefaults() {
	mapfile  -n 10 -t defaultNames < <( bspc query --names -D )
}

renameDesktop() {
	local desktopIDs="$@"
	for desktopID in ${desktopIDs[@]}; do
		echo " - Renaming desktopID: $desktopID"

		desktopName="$(bspc query --names --desktop "$desktopID" --desktops)"
		echo -e " -- Current Desktop Name: ${GREEN}$desktopName ${R}"
		
		monitorID="$(bspc query --desktop "$desktopID" --monitors)"
		echo " -- monitorID: $monitorID"

		desktopIndex="$(bspc query -m "$monitorID" --desktops | grep -n "$desktopID" | cut -d ':' -f 1)"
		echo " -- desktopIndex: $desktopIndex"

		# for node (window) on this desktop, get children processes and categories
		children=""
		desktopCategories=""
		for node in $(bspc query -m "$monitorID" -d "$desktopID" -N); do

			# get node's pid
			pid=$(xprop -id "$node" _NET_WM_PID 2>/dev/null | awk '{print $3}')
			if [ "$pid" != "" -a "$pid" != " " ]; then
				children+="$(pstree -AT "$pid")\n"
				desktopCategories+="$(getCategories "$pid")"
			fi

			echo " -- Node, pid: $node, $pid"
		done
		echo -e " -- All Processes:\n$children"
		echo -e " -- All Categories:\n$desktopCategories\n"

		name=""

		# if program has no categories or missing one, add them here
		case "$children" in
			*firefox*) desktopCategories+="firefox" ;;
			*weechat*) desktopCategories+="Chat" ;;
			*calibre*) desktopCategories+="Viewer" ;;
			*soffice*) desktopCategories+="Office" ;;
			*micro*) desktopCategories+="Office" ;;
			*urxvt*) desktopCategories+="TerminalEmulator" ;;
		esac

		# name desktop based on found categories
		# stops at first match
		case "$desktopCategories" in
			*firefox*)		name="" ;;
			*WebBrowser*)		name="" ;;
			*Documentation*|*Office*|*Spreadsheet*|*WordProcessor*)
						name="" ;;
			*Viewer*)		name="" ;;
			*Game*|*game*)
						name="" ;;
			*Engineering*)		name="" ;;
			*Graphics*)		name="" ;;
			*Audio*|*Music*)	name="" ;;
			*Chat*|*InstantMessaging*|*IRCClient*)
						name="" ;;
			*Email*)		name="" ;;
			*Archiving*)		name="" ;;
			*Player*)		name="" ;;
			*Calculator*)		name="" ;;
			*Calendar*)		name="" ;;
			*Clock*)		name="" ;;
			*ContactManagement*)	name="" ;;
			*Database*)		name="" ;;
			*Dictionary*)		name="" ;;
			*DiscBurning*)		name="" ;;
			*Math*)			name="" ;;
			*PackageManager*)	name="" ;;
			*Photography*)		name="" ;;
			*Presentation*)		name="廊" ;;
			*Recorder*)		name="壘" ;;
			*Science*)		name="" ;;
			*Settings*)		name="" ;;
			*FileManager*|*Filesystem*|*FileTools*)
						name="" ;;
			*IDE*|*TextEditor*) 	name="" ;;
			*TerminalEmulator*)	name="" ;;
		esac

		# fallback names
		[ "${#name}" -eq 0 ] && [ "${#desktopCategories}" -gt 0  -o "${#children}" -gt 0 ] && name=""	# no recognized applications
		[ -z "$name" ] && name=${defaultNames["$((desktopIndex-1))"]}	# no applications

		echo -e " -- New Name: ${BLUE}$name ${R}\n"
		bspc desktop "$desktopID" --rename "$name"
	done
}

renameMonitor() {
	monitorID="$1"	
	echo "Renaming monitor: $monitorID"
	for desktop in $(bspc query -m "$monitorID" -D); do	
		renameDesktop "$desktop"
	done
}

renameAll() {	
	echo "Renaming everything..."
	for monitorID in $(bspc query -M); do
		renameMonitor "$monitorID"
	done
}

#Get defaults before monitoring
declare -a desknameDefaults
getDefaults

monitor() {
	bspc subscribe monitor_add monitor_remove monitor_swap desktop_add desktop_remove desktop_swap desktop_transfer node_add node_remove node_swap node_transfer | while read -r line; do	# trigger on any bspwm event

		echo -e "${RED}trigger:${R} $line"
		case "$line" in
			monitor*) renameAll ;;
			desktop_add*|desktop_remove*) renameAll ;;
			desktop_swap*) renameDesktop "$(echo "$line" | awk '{print $3,$5}')" ;;
			desktop_transfer*) renameDesktop "$(echo "$line" | awk '{print $3}')" ;;
			node_add*|node_remove*) renameDesktop "$(echo "$line" | awk '{print $3}')" ;;
			node_swap*|node_transfer*) renameDesktop "$(echo "$line" | awk '{print $3,$6}')" ;;
		esac
	done
}

flag_h=0
recursive=1
mode="monitor"

OPTS="hacns:g:"	# the colon means it requires a value
LONGOPTS="help,all,categories,norecursive,search,get"

parsed=$(getopt --options=$OPTS --longoptions=$LONGOPTS -- "$@")
eval set -- "${parsed[@]}"

while true; do
	case "$1" in
		-h|--help)
			flag_h=1
			shift
			;;

		-a|--all)
			mode="getAllApplications"
			shift
			;;

		-c|--categories)
			mode="getAllCategories"
			shift
			;;

		-s|--search)
			mode="search"
			application="$2"
			shift 2
			;;

		-g|--get)
			mode="get"
			application="$2"
			shift 2
			;;

		-n|--norecursive)
			recursive=0
			shift
			;;

		--) # end of arguments
			shift
			break
			;;

		*)
			printf '%s\n' "Error while parsing CLI options" 1>&2
			flag_h=1
			;;
	esac
done

HELP="\
Usage: desknamer [OPTIONS]

desknamer.sh monitors your open desktops and renames them according to what's inside.

optional args:
  -a, --all             print all applications found on your machine
  -c, --categories      print all categories found on your machine
  -n, --norecursive     don't inspect windows recursively
  -s, --search PROGRAM  find .desktop files matching *program*.desktop
  -g, --get PROGRAM     get categories for given program
  -h, --help            show help"

if ((flag_h)); then
	printf '%s\n' "$HELP"
	exit 0
fi

case "$mode" in
	getAllApplications) getAllApplications ;;
	getAllCategories) getAllCategories ;;
	monitor) monitor ;;
	search) find -L /usr/share/applications /usr/local/share/applications ~/.local/share/applications -iname "*$application"*.desktop 2>/dev/null ;;
	get) getCategory "$application" ;;
esac
