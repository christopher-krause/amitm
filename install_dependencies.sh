#!/bin/bash


# Utils
function check() {
	STATE=$OK
	if [ -z "$1" ]; then
		STATE=$FAIL
	fi
	CHECK="`$1 $2 >/dev/null 2>&1 || echo "FAILD"`"
	if [ "$CHECK" == "FAILD" ]; then
		STATE=$FAIL
	fi
}

function checkarpoison() {
	STATE=$OK
	CHECK="`arpoison >/dev/null 2>&1`"
	if [ $? -gt 1 ]; then
		STATE=$FAIL
	fi
}
# Install function
function installHomebrew() {
	echo -e "${OK}Install Homebrew"
	INSTALLED=`"ruby -e $(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" >/dev/null 2>&1 || echo "FAILD"`
	if [ "$INSTALLED" == "FAILD" ]; then
		echo -e "${FAIL}Somthing went wrong... cant install homebrew"
		exit 1
	fi
}

function installViaBrew() {
	echo -e "${OK}Install $1"
	INSTALLED=`brew install $1 >/dev/null 2>&1 || echo "FAILD"`
	if [ "$INSTALLED" == "FAILD" ]; then
		echo -e "${FAIL}Somthing went wrong... cant install $1"
		exit 1
	fi
}

# COLORS
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
BOLD='\033[1m'
NOFO='\033[00m'
OK="${GREEN}[+] ${NC}"
FAIL="${RED}[-] ${NC}"

HAS_ARPOISEN=1
HAS_MITMPROXY=1
HAS_HOMEBREW=1

echo -e "${OK}Install mitm_arp_proxy dependencies"

# Check if dependecies are installed
checkarpoison
if [ "$CHECK" == "FAILD" ]; then
	HAS_ARPOISEN=0
fi
echo -e "${STATE} -> arpoison"

check mitmproxy --version
if [ "$CHECK" == "FAILD" ]; then
	HAS_MITMPROXY=0
fi
echo -e "${STATE} -> mitmproxy"

check brew --version
if [ "$CHECK" == "FAILD" ]; then
	HAS_HOMEBREW=0
fi
echo -e "${STATE} -> Homebrew"

# Install dependecies
if [ "$HAS_HOMEBREW" == 0 ]; then
	installHomebrew
fi

if [ "$HAS_MITMPROXY" == 0 ]; then
	installViaBrew mitmproxy
fi

if [ "$HAS_ARPOISEN" == 0 ]; then
	installViaBrew arpoison
fi

echo -e "${OK}All dependencies are installed"

