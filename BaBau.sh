#!/bin/bash

##############################################################################################################
# Filename - BaBau.sh                                                                                        #
# Description - automatic Local Redirection Through Tor                                                      #
# Date - 07/02/2017                                                                                          #
##############################################################################################################

#Config file
TORCONFIGFILE="/etc/tor/torrc"
PRIVOXYCONFIGFILE="/etc/privoxy/config"
RESOLVFILE="/etc/resolv.conf"

#Program
IPCOMM="/sbin/iptables"

#Colors
red='\e[0;31m'
NC='\e[0m' 
green='\e[;32m'

#store your external IP in a tmp file
curl -s http://whatismyip.akamai.com/ > /tmp/myip
#################################################################################################################








echo -e "\n*** Babau - automatic Local Redirection Through Tor ***"
if [ "$(whoami)" != 'root' ]; then
        echo -e "\nYou can't use $0 as normal user. You must be root!"
        sleep 2
        exit 1;
        
        else
        echo -e "\nOK! You're root, go on..."
        sleep 1
fi


command -v tor >/dev/null 2>&1 || { echo >&2 "Tor not installed.  Exit."; exit 1; }
command -v privoxy >/dev/null 2>&1 || { echo >&2 "Privoxy not installed.  Exit."; exit 1; }
command -v iptables >/dev/null 2>&1 || { echo >&2 "Iptables not installed.  Exit."; exit 1; }
command -v 'grep' >/dev/null 2>&1 || { echo >&2 "Grep not installed.  Exit."; exit 1; }
command -v curl >/dev/null 2>&1 || { echo >&2 "Curl not installed.  Exit."; exit 1; }

MENU="
Menu:
 1)  Start BaBau
 2)  Clean BaBau
 3)  Test BaBau
 4)  Exit

Scelta: "

while true ; do
clear
echo -en "${red}$MENU${NC}"
read OPTIONS


case $OPTIONS in


1)
STARTBABAU=" 
  #############################################################
  #                       Starting BaBau                      #
  #############################################################
"

echo "$STARTBABAU"

echo -e "\n${green}Checking: $TORCONFIGFILE . . .${NC}"
if [ -f $TORCONFIGFILE ];
then
   mv $TORCONFIGFILE "$TORCONFIGFILE".bk
   echo -e "${green}Backup created: $TORCONFIGFILE.bk${NC}"
   cat <<EOF >$TORCONFIGFILE
Log notice file /var/log/tor/notices.log
RunAsDaemon 1
AutomapHostsOnResolve 1
TransPort 9040
DNSPort 5353
EOF
   echo -e "${green}Created: $TORCONFIGFILE${NC}"
   else 
   echo -e "${red}Error!"
   exit
fi

echo -e "\n${green}Checking: $PRIVOXYCONFIGFILE . . .${NC}"
if [ -f $PRIVOXYCONFIGFILE ];
then
   mv $PRIVOXYCONFIGFILE "$PRIVOXYCONFIGFILE".bk
   echo -e "${green}Backup created: $PRIVOXYCONFIGFILE.bk${NC}"
   cat <<EOF >$PRIVOXYCONFIGFILE
user-manual /usr/share/doc/privoxy/user-manual
confdir /etc/privoxy
logdir /var/log/privoxy
actionsfile match-all.action 
actionsfile default.action   
actionsfile user.action 
filterfile default.filter
filterfile user.filter      
logfile logfile
listen-address  127.0.0.1:8118
listen-address  [::1]:8118
toggle  1
enable-remote-toggle  0
enable-remote-http-toggle  0
enable-edit-actions 0
enforce-blocks 0
buffer-limit 4096
enable-proxy-authentication-forwarding 0
forwarded-connect-retries  0
accept-intercepted-requests 0
allow-cgi-request-crunching 0
split-large-forms 0
keep-alive-timeout 5
tolerate-pipelining 1
socket-timeout 300
forward-socks5t   /               127.0.0.1:9050 .
EOF
   echo -e "${green}Created: $PRIVOXYCONFIGFILE${NC}"
   else 
   echo -e "${red}Error!"
   exit
fi

echo -e "\n${green}Checking: $RESOLVFILE . . .${NC}"
if [ -f $RESOLVFILE ];
then
   mv $RESOLVFILE "$RESOLVFILE".bk
   echo -e "${green}Backup created: $RESOLVFILE.bk${NC}"
   cat <<EOF >$RESOLVFILE
nameserver 127.0.0.1
EOF
   echo -e "${green}Created: $TORCONFIGFILE${NC}"
   else 
   echo -e "${red}Error!"
   exit
fi

echo -e "\n${green}Flush iptables${NC}"

$IPCOMM -F
$IPCOMM -X
$IPCOMM -t nat -F
$IPCOMM -t nat -X
$IPCOMM -t mangle -F
$IPCOMM -t mangle -X
$IPCOMM -t raw -F
$IPCOMM -t raw -X

#the UID that Tor runs as 
_tor_uid=$(cat /etc/passwd | grep debian-tor | awk -F ":" '{print $3}')

#Tor's TransPort
_trans_port=$(cat /etc/tor/torrc | grep TransPort | awk '{ print $NF }')

#your default network interface
_net_if=$(route | grep '^default' | grep -o '[^ ]*$')

#Tor's DNSPort
_dns_port=$(cat /etc/tor/torrc | grep DNSPort | awk '{ print $NF }')

#LAN destinations that shouldn't be routed through Tor
#Check reserved block.
_non_tor="127.0.0.0/8 10.0.0.0/8 172.16.0.0/24 192.168.0.0/24 192.168.1.0/24"

#Other IANA reserved blocks (These are not processed by tor and dropped by default)
_resv_iana="0.0.0.0/8 100.64.0.0/10 169.254.0.0/16 192.0.0.0/24 192.0.2.0/24 192.88.99.0/24 198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/3"

echo -e "${green}Set new iptables rules${NC}\n"

#nat dns requests to Tor
iptables -t nat -A OUTPUT -d 127.0.0.1/32 -p udp -m udp --dport 53 -j REDIRECT --to-ports $_dns_port


#don't nat the Tor process, the loopback, or the local network
$IPCOMM  -t nat -A OUTPUT -m owner --uid-owner $_tor_uid -j RETURN
$IPCOMM  -t nat -A OUTPUT -o lo -j RETURN


for _lan in $_non_tor; do
 $IPCOMM  -t nat -A OUTPUT -d $_lan -j RETURN
done

for _iana in $_resv_iana; do
 $IPCOMM  -t nat -A OUTPUT -d $_iana -j RETURN
done

### Don't lock yourself out after the flush
$IPCOMM -P INPUT ACCEPT
$IPCOMM -P OUTPUT ACCEPT

#redirect whatever fell thru to Tor's TransPort
$IPCOMM -t nat -A OUTPUT -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -j REDIRECT --to-ports $_trans_port

### set iptables *filter
#*filter INPUT
$IPCOMM -A INPUT -m state --state ESTABLISHED -j ACCEPT
$IPCOMM -A INPUT -i lo -j ACCEPT
$IPCOMM -A INPUT -j DROP

#*filter FORWARD
iptables -A FORWARD -j DROP

#*filter OUTPUT
#possible leak fix. See warning.
$IPCOMM -A OUTPUT -m state --state INVALID -j DROP

$IPCOMM -A OUTPUT -m state --state ESTABLISHED -j ACCEPT

#allow Tor process output
$IPCOMM -A OUTPUT -o $_net_if -m owner --uid-owner $_tor_uid -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -m state --state NEW -j ACCEPT

#allow loopback output
$IPCOMM -A OUTPUT -d 127.0.0.1/32 -o lo -j ACCEPT

#tor transproxy magic
$IPCOMM -A OUTPUT -d 127.0.0.1/32 -p tcp -m tcp --dport $_trans_port --tcp-flags FIN,SYN,RST,ACK SYN -j ACCEPT

#Log & Drop everything else.
$IPCOMM -A OUTPUT -j LOG --log-prefix "Dropped OUTPUT packet: " --log-level 7 --log-uid
$IPCOMM -A OUTPUT -j DROP

#Set default policies to DROP
$IPCOMM -P INPUT DROP
$IPCOMM -P FORWARD DROP
$IPCOMM -P OUTPUT DROP

echo -e "${green}Starting services. . . ${NC}\n"
service tor start && service privoxy start


echo -e "\n${green}ALL DONE!${NC}\n\n\n"
echo Press RETURN to continue
read
;;


2)
CLEANBABAU=" 
  #############################################################
  #                        Clean setup                        #
  #############################################################
"

echo "$CLEANBABAU"

rm -rf /tmp/myip 2> /dev/null
echo -e "\n${green}Restoring Tor config file . . .${NC}"
if [ -f $TORCONFIGFILE.bk ];
	then 
	mv  "$TORCONFIGFILE".bk $TORCONFIGFILE 
	else
	echo -e "Tor config file not found"
fi

echo -e "\n${green}Restoring Privoxy config file . . .${NC}"
if [ -f $PRIVOXYCONFIGFILE.bk ];
	then 
	mv  "$PRIVOXYCONFIGFILE".bk $PRIVOXYCONFIGFILE
	else
	echo -e "Privoxy config file not found"
fi

echo -e "\n${green}Restoring /etc/resolv.conf . . .${NC}"
if [ -f $RESOLVFILE.bk ];
	then 
	mv  "$RESOLVFILE".bk $RESOLVFILE
	else
	echo -e "/etc/resolv.conf config file not found"

fi

echo -e "\n${green}Stopping services. . . ${NC}"
service tor stop && service privoxy stop

echo -e "\n${green}Flushing iptables . . .${NC}\n\n\n"

	### Don't lock yourself out after the flush
	$IPCOMM -P INPUT ACCEPT
	$IPCOMM -P OUTPUT ACCEPT
	##other clening rules
	$IPCOMM -F
	$IPCOMM -X
	$IPCOMM -t nat -F
	$IPCOMM -t nat -X
	$IPCOMM -t mangle -F
	$IPCOMM -t mangle -X
	$IPCOMM -t raw -F
	$IPCOMM -t raw -X

if [ -f $RESOLVFILE.bk ] && [ -f $PRIVOXYCONFIGFILE.bk ] && [ -f $TORCONFIGFILE.bk ] 
	then
	echo -e "Something bad happened.\n"
	exit 1
fi

echo Press RETURN to continue
read	
;;

3)
TESTBABAU=" 
  #############################################################
  #                       Testing BaBau                       #
  #############################################################
"

echo "$TESTBABAU"

echo -en "\n${green}Your old IP address: ${NC}"
cat /tmp/myip 2> /dev/null
echo -en "${green}\nYour IP address through TOR: ${NC}"
curl -s http://whatismyip.akamai.com/
echo -en "\n\n\n"
echo Press RETURN to continue
read
;;

4)
echo "$EXITBABAU"
echo -e "${red}\nGoing away . . .\n${NC}"
exit 0
;;

*)
clear
echo -e "\nWrong button\n"
sleep 1
;;

esac
done


