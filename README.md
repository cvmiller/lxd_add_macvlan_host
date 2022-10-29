# lxd_add_macvlan_host script to enable a container to communicate with a LXD Host

LXD supports several container interface types. While the **bridging** type is the easiest to understand from a networking point of view, it takes a fair amount of setup, and can be tricky.

LXD also support **MACVLAN** type of interface with eliminates the complexity of getting your container connected to a LAN, and then the Internet. However, there is a limitation, in that in the default config, the Linux Container can talk to the internet, but it can't talk to the host it is residing on.

## A word about creating MACVLAN interfaces in LXD

In order for your linux container to reach the internet, it easy to use a profile which attaches the NIC interface of your container to a MACVLAN interface. With the host interface being **eth0**, a typical profile would look like:

```
$ lxc profile show enet
config: {}
description: Default LXD profile
devices:
  eth0:
    nictype: macvlan
    parent: eth0
    type: nic
  root:
    path: /
    pool: default
    type: disk
name: enet
used_by:
- /1.0/instances/test
- /1.0/instances/lxdware
```
You would launch a container using the MACVLAN profile using `-p enet`

```
lxc launch -p enet images:alpine/3.16 test
```

Your container should get IP addresses from your router (via DHCP and SLAAC), rather than having to hard code them. And your container should be able to ping the outside world (e.g. the internet)

## What lxd_add_macvlan_host.sh does

`lxd_add_macvlan_host.sh` script solves this problem by creating an additional MACVLAN interface on the host, and adjusting routes so that the new interface is preferred.

The script should be run on the **LXD Host** *not* in the container (which already has a MACVLAN interface)

### Running the script

`lxd_add_macvlan_host.sh` requires sudo privileges (to add interfaces and adjust routes), and will request a password when required.

There are two parameters `-a` to add the **MACVLAN** interface to the host, and `-r` to remove the interface.

```
$ ./lxd_add_macvlan_host.sh -h
	./lxd_add_macvlan_host.sh - creates MACVLAN interface on LXD Host 
	e.g. ./lxd_add_macvlan_host.sh -a 
	-a  Add MACVLAN interface
	-r  Remove MACVLAN interface
	-i  use this interface e.g. eth0
	
 By Craig Miller - Version: 0.93

```

#### Adding a MACVLAN interface on the LXD Host

Adding a MACVLAN to the host is easy.

```
$ ./lxd_add_macvlan_host.sh -a
Requesting Sudo Privlages...
Working ....
Interface: host-shim added
Pau
```

Looking at IP interfaces, you will see both IPv4 and IPv6 addresses added to the new interface:

```
$ ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether b8:27:eb:6c:02:88 brd ff:ff:ff:ff:ff:ff
    inet 192.168.215.140/24 brd 192.168.215.255 scope global dynamic noprefixroute eth0
       valid_lft 3502sec preferred_lft 2865sec
    inet6 fd73:c73c:444::103/128 scope global noprefixroute 
       valid_lft forever preferred_lft forever
    inet6 2001:db8:8011:fd44::103/128 scope global noprefixroute 
       valid_lft forever preferred_lft forever
    inet6 fd73:c73c:444:0:1b7a:1fb2:4171:5737/64 scope global mngtmpaddr noprefixroute 
       valid_lft forever preferred_lft forever
    inet6 2001:db8:8011:fd44:8687:505b:cb5f:6939/64 scope global mngtmpaddr noprefixroute 
       valid_lft forever preferred_lft forever
    inet6 fe80::d773:edc1:2b0e:fad4/64 scope link 
       valid_lft forever preferred_lft forever
3: wlan0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether b8:27:eb:39:57:dd brd ff:ff:ff:ff:ff:ff
4: lxdbr0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default qlen 1000
    link/ether 00:16:3e:82:62:46 brd ff:ff:ff:ff:ff:ff
25: host-shim@eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 02:27:eb:6c:02:88 brd ff:ff:ff:ff:ff:ff
    inet 192.168.215.184/24 brd 192.168.215.255 scope global dynamic noprefixroute host-shim
       valid_lft 3533sec preferred_lft 3083sec
    inet6 fd73:c73c:444::103/128 scope global noprefixroute 
       valid_lft forever preferred_lft forever
    inet6 2001:db8:8011:fd44::103/128 scope global noprefixroute 
       valid_lft forever preferred_lft forever
    inet6 fd73:c73c:444:0:8ab4:f532:6019:46d4/64 scope global mngtmpaddr noprefixroute 
       valid_lft forever preferred_lft forever
    inet6 2001:db8:8011:fd44:ee65:9a69:2e24:f3d1/64 scope global mngtmpaddr noprefixroute 
       valid_lft forever preferred_lft forever
    inet6 fe80::15d5:27a6:2bf8:e246/64 scope link 
       valid_lft forever preferred_lft forever

```

#### Removing a MACVLAN interface on the LXD Host

Removing a MACVLAN to the host is also easy. Initially, I put in the remove option for ease of testing, but there may be a need for removing the MACVLAN interface on the *HOST*.

```
$ ./lxd_add_macvlan_host.sh -r
Requesting Sudo Privlages...
Interface: host-shim REMOVED
Pau
```

## Why is it written in Bash?

For two reasons:

1. Bash runs everywhere, from Raspberry Pi, to Windows Subsystem for Linux (WSL).
2. It is easy to read, and therefore the source is easy to validate.

## Limitations

The script requires the most of the shell script collection of utilities (e.g. ip, grep, awk) which is probably already installed on your Linux system.

The script currently only supports global IPv6 addresses. This means in your container, you will have to use the host MACVLAN IPv6 address to reach the host. IPv4 is not currently supported.





