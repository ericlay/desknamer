#!/usr/bin/env bash

# this program automatically renames *existing* desktops according to
# what's running inside. If you wish to add more desktops to a certain monitor,
# you must run 'bspc monitor -d 1 2 3 4 5...' on that monitor to give it
# the desired number of desktops.

BLUE='\e[34m'
GREEN='\e[32m'
RED='\e[31m'
R='\e[0m'

getSystemCategories() {	
	menuItems="$(find /usr/share/applications /usr/local/share/applications ~/.local/share/applications -name *.desktop)"

	for menuItem in $menuItems; do
		categories="$(grep -P '^Categories=' "$menuItem" | cut -d '=' -f 2)"
		IFS=';'
		for category in $categories; do
			everyCategory+="$category\n"
		done
	done

	echo -e "$everyCategory" | sort -u
}

getCategories() {	
	local pid="$1"
	[ "$pid" == "" -o "$pid" == " " ] && return

	comm="$(cat "/proc/$pid/comm" 2>/dev/null | tr '\0' '\n')"
	[ "$comm" == "" ] && return

	menuItem="$(find /usr/share/applications /usr/local/share/applications ~/.local/share/applications -iname "$comm".desktop | head -1)"

	if [ "$menuItem" != "" ]; then
		categories="$(grep -P '^Categories=' "$menuItem" | cut -d '=' -f 2)"
		echo "$categories"
	fi

	children="$(ps --no-headers --ppid "$pid" 2>/dev/null | awk '{print $1}')"
	((recursive)) && for childPID in $children; do
		getCategories "$childPID"
	done
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
				children+="$(pstree -AT "$pid")"
				desktopCategories+="$(getCategories "$pid")"
			fi

			echo " -- Node: $node:$pid"
		done
		echo -e " -- All Processes:\n$children"
		echo -e " -- All Categories:\n$desktopCategories"

		name=""

		# name desktop based on found categories
		# stops at first match
		case "$desktopCategories" in
			*WebBrowser*)		name="" ;;
			*Documentation*|*Office*|*Spreadsheet*|*WordProcessor*)
						name="" ;;
			*Game*|*game*)
						name="" ;;
			*Graphics*)		name="" ;;
			*Audio*|*Music*)	name="" ;;
			*Chat*|*InstantMessaging*|*IRCClient*)
						name="" ;;
			*Email*)		name="" ;;
			*Archiving*)		name="" ;;
			*Player*)		name="" ;;
			*Calculator*)		name="" ;;
			*Calendar*)		name="" ;;
			*Clock*)		name="" ;;
			*ContactManagement*)	name="﯉" ;;
			*Database*)		name="" ;;
			*Dictionary*)		name="﬜" ;;
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

		# name desktop depending on child processes
		# stops at first match
		case "$children" in
			*freecad*) name="" ;;
			*firefox*) name="" ;;
			*weechat*) name="" ;;
		esac

		# fallback names
		[ "${#name}" -eq 0 ] && [ "${#desktopCategories}" -gt 0  -o "${#children}" -gt 0 ] && name=""	# no recognized applications
		[ "$name" == "" ] && name="$desktopIndex"	# no applications

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

OPTS="han"	# the colon means it requires a value
LONGOPTS="help,all,norecursive"

parsed=$(getopt --options=$OPTS --longoptions=$LONGOPTS -- "$@")
eval set -- "${parsed[@]}"

while true; do
	case "$1" in
		-h|--help)
			flag_h=1
			shift
			;;

		-a|--all)
			mode="printAll"
			shift
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
  -a, --all           print all application categories found on your machine
  -n, --norecursive   don't inspect windows recursively
  -h, --help          show help"

if ((flag_h)); then
	printf '%s\n' "$HELP"
	exit 0
fi

case "$mode" in
	printAll) getSystemCategories ;;
	monitor) monitor ;;
esac
