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
#		Only works for IPv6 global Unicast Addresses (at the moment)
#
#
#


function usage {
               echo "	$0 - creates LXD Host MACVLAN "
	       echo "	e.g. $0 -D -p "
	       echo "	-a  Add MACVLAN interface"
	       echo "	-r  Remove MACVLAN interface"
	       echo "	-i  use this interface e.g. eth0"

	       echo "	"
	       echo " By Craig Miller - Version: $VERSION"
	       exit 1
           }

VERSION=0.92

# initialize some vars

# ip command full path
ip="/usr/sbin/ip"

# Ethernet interface on the Pi
INTF="eth0"
MACVLAN_INTF="host-shim"

ADDINTF=0
REMOVE=0

SLEEPTIME=5		#wait for interface to come up

DEBUG=0

while getopts "?hdra" options; do
  case $options in
    p ) PING=1
    	(( numopts++));;
    r ) REMOVE=1
    	(( numopts++));;
    a ) ADDINTF=1
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

# check that there are no arguments left to process
if [ $# -ne 0 ]; then
	usage
	exit 1
fi

#======== Actual work performed by script ============

# elevate to sudo
uid=$(sudo id | grep -E -o 'uid=([0-9]+)')
if [ "$uid" != "uid=0" ]; then
	echo "Error: Script requires sudo privilages"
	usage
	exit 1
fi

# determine global prefix for $INTF
prefix=$($ip -6 route | grep $INTF | grep '^2' | cut -f 1 -d " ")

if (( DEBUG == 1 )); then
	echo "Global prefix = $prefix"
fi

# add interface and route
if (( ADDINTF == 1 )); then
	# check that interface doesn't already exist
	intf=$($ip addr | grep -E -o $MACVLAN_INTF | head -1)
	if [ "$intf" != "" ]; then
		echo "WARNING: Interface $intf already exists!"
		usage
		exit 1
	fi
	
	# create a local administered MAC address for the MACVLAN interface
	ETH_ADDR=$(ip link show dev $INTF | grep ether | awk '{print $2}' | sed -r 's/^[0-9a-f]{2}/02/')

	# create host MACVLAN interface
	sudo $ip link add $MACVLAN_INTF link $INTF type macvlan  mode bridge
	# set static MAC address
	sudo $ip link set address $ETH_ADDR dev $MACVLAN_INTF
	
	# let user know something is happening
	echo "Working ...."
	# give interface time to come up
	sleep $SLEEPTIME
	
	# add route so that host will prefer MACVLAN interface
	sudo $ip route add "$prefix" dev $MACVLAN_INTF metric 100 pref high
	
	echo "Interface: $MACVLAN_INTF added"
else	
	# remove route so that host will prefer MACVLAN interface
	sudo $ip route del "$prefix" dev $MACVLAN_INTF metric 100
	
	# Remove host MACVLAN interface
	sudo $ip link del $MACVLAN_INTF link $INTF type macvlan  mode bridge
	
	echo "Interface: $MACVLAN_INTF REMOVED"
fi


if (( DEBUG == 1 )); then
	# show ip interfaces and routes
	echo "### show host networking"
	$ip addr

	$ip -6 route
fi

# let the user know the script is done
echo "Pau"



