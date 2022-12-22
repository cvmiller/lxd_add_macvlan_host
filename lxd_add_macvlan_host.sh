#!/usr/bin/env bash

##################################################################################
#
#  Copyright (C) 2015-2018 Craig Miller
#
#  See the file "LICENSE" for information on usage and redistribution
#  of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#  Distributed under GPLv2 License
#
##################################################################################


#
#	Script creates LXD Host MACVLAN interface
#
#	by Craig Miller		25 October 2022

#	
#	Assumptions:
#		Uses sudo privilages
#		Prefers IPv6 GUA, if present, over ULA
#		If multiple GUA prefixes are present, script will pick the first it finds
#
#	22 Dec 2022 - updated to support IPv4
#


function usage {
               echo "	$0 - creates MACVLAN interface on LXD Host "
	       echo "	e.g. $0 -a "
	       echo "	-a  Add MACVLAN interface"
	       echo "	-4  Add MACVLAN IPv4 interface"
	       echo "	-r  Remove MACVLAN interface"
	       echo "	-i  use this interface e.g. eth0"

	       echo "	"
	       echo " By Craig Miller - Version: $VERSION"
	       exit 1
           }

VERSION=0.95

# initialize some vars

# ip command full path
ip="/usr/sbin/ip"

# Ethernet interface on the Pi
INTF="eth0"
MACVLAN_INTF="host-shim"

ADDINTF=0
REMOVE=0
IPV4=0

SLEEPTIME=5		#wait for interface to come up

DEBUG=0

# check if there are no arguments 
if [ $# -eq 0 ]; then
	usage
	exit 1
fi

while getopts "?hdra4i:" options; do
  case $options in
    r ) REMOVE=1
    	(( numopts++));;
    a ) ADDINTF=1
    	(( numopts++));;
    4 ) IPV4=1
    	(( numopts++));;
    i ) INTF=$OPTARG
    	numopts=$(( numopts + 2));;
    d ) DEBUG=1
    	(( numopts++));;
    h ) usage;;
    \? ) usage	# show usage with flag and no value
         exit 1;;
    * ) usage		# show usage with unknown flag
    	 exit 1;;
  esac
done
# remove the options as cli arguments
shift "$numopts"

# check that there are no unused arguments left to process
if [ $# -ne 0 ]; then
	usage
	exit 1
fi

function log {
	#
	#	Common print function 
	#
	str=$(echo "$*" | tr '\n' ' ' )
	if [ -t 1 ]; then 
		# use colour for headings
		echo -e "\033[1;31m$str\033[00m" 
	else
		# no colour
		echo -e "$str"
	fi

	}

function req_sudo {
	#
	#	Common sudo authorization function 
	#
	# elevate to sudo
	echo "Requesting Sudo Privlages..."
	uid=$(sudo id | grep -E -o 'uid=([0-9]+)')
	if [ "$uid" != "uid=0" ]; then
		log "Error: Script requires sudo privilages" 
		usage
		exit 1
	fi

	}


#======== Actual work performed by script ============

# determine path to ip command
ip_cmd=$(which ip)
if [ "$ip_cmd" != "$ip" ]; then
	ip="$ip_cmd"
fi

# validate ethernet Interface
discovered_intf=$($ip link | grep "$INTF" )
if [ "$discovered_intf" == "" ]; then
	log "Error: No interface $INTF found" 
	usage
	exit 1
fi

prefix=""
# determine global & ULA prefix for $INTF
prefix=$($ip -6 route | grep "$INTF" | grep '^2' | cut -f 1 -d " " | head -1)
ula_prefix=$($ip -6 route | grep "$INTF" | grep '^fd' | cut -f 1 -d " " | head -1)

# determine v4 subnet
v4_prefix=""
if (( IPV4 == 1 )); then
	v4_prefix=$($ip -4 route | grep eth0 | grep -E '(^192|^10|^172)' | cut -f 1 -d " " | head -1)
fi

if (( DEBUG == 1 )); then
	echo "Global prefix = $prefix | ULA prefix = $ula_prefix | IPv4 subnet = $v4_prefix"
fi

# add interface and route
if (( ADDINTF == 1 )); then
	# check that interface doesn't already exist
	intf=$($ip addr | grep -E -o $MACVLAN_INTF | head -1)
	if [ "$intf" != "" ]; then
		log "WARNING: Interface $intf already exists!"
		usage
		exit 1
	fi
	
	# create a local administered MAC address for the MACVLAN interface
	ETH_ADDR=$(ip link show dev "$INTF" | grep ether | awk '{print $2}' | sed -r 's/^[0-9a-f]{2}/02/')

	# elevate to sudo
	req_sudo

	# create host MACVLAN interface
	sudo $ip link add $MACVLAN_INTF link "$INTF" type macvlan  mode bridge
	# set static MAC address
	sudo $ip link set address "$ETH_ADDR" dev "$MACVLAN_INTF"
	
	# let user know something is happening
	echo "Working ...."
	# give interface time to come up
	sleep $SLEEPTIME
	
	# add route so that host will prefer MACVLAN interface, prefer global over ULA
	if [ "$prefix" != "" ]; then
		sudo $ip route add "$prefix" dev $MACVLAN_INTF metric 100 pref high
	else
		sudo $ip route add "$ula_prefix" dev $MACVLAN_INTF metric 100 pref high
	fi
	
	# add IPv4 route
	if (( IPV4 == 1 )); then
		echo "Waiting for IPv4 DHCP ...."
		# give interface time to come up
		sleep $SLEEPTIME
	
		sudo $ip route add "$v4_prefix" dev $MACVLAN_INTF metric 100 pref high
	fi
	
	echo "Interface: $MACVLAN_INTF added"
elif (( REMOVE == 1 )); then	

	# elevate to sudo
	req_sudo

	# remove route so that host will prefer MACVLAN interface
	sudo $ip route del "$prefix" dev $MACVLAN_INTF metric 100 2> /dev/null
	sudo $ip route del "$ula_prefix" dev $MACVLAN_INTF metric 100 2> /dev/null
	sudo $ip route del "$v4_prefix" dev $MACVLAN_INTF metric 100 2> /dev/null
	
	# Remove host MACVLAN interface
	sudo $ip link del $MACVLAN_INTF link "$INTF" type macvlan  mode bridge
	
	echo "Interface: $MACVLAN_INTF REMOVED"
fi


if (( DEBUG == 1 )); then
	# show ip interfaces and routes
	echo "### show host networking"
	$ip addr

	$ip -6 route
	$ip -4 route
fi

# let the user know the script is done
echo "Pau"



