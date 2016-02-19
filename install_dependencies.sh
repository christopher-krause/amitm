#!/bin/bash

# Utils
function check() {
	STATE=$OK
	if [ -z "$1" ]; then
		STATE=$FAIL
	fi
	CHECK="`$1 $2 >/dev/null 2>&1 || echo "FAILED"`"
	if [ "$CHECK" == "FAILED" ]; then
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
	INSTALLED=`"ruby -e $(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" >/dev/null 2>&1 || echo "FAILED"`
	if [ "$INSTALLED" == "FAILED" ]; then
		echo -e "${FAIL}Somthing went wrong... cant install homebrew"
		exit 1
	fi
}

function installViaBrew() {
	echo -e "${OK}Install $1"
	INSTALLED=`brew install $1 >/dev/null 2>&1 || echo "FAILED"`
	if [ "$INSTALLED" == "FAILED" ]; then
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

HAS_ARPOISON=0 # Default not installed, cant check for arpoinson at the moment
HAS_MITMPROXY=1
HAS_HOMEBREW=1
HAS_NMAP=1

echo -e "${OK}Install mitm_arp_proxy dependencies"

# Check if dependecies are installed
checkarpoison
if [ "$CHECK" == "FAILED" ]; then
	HAS_ARPOISON=0
fi
echo -e "${STATE} -> arpoison"

check mitmproxy --version
if [ "$CHECK" == "FAILED" ]; then
	HAS_MITMPROXY=0
fi
echo -e "${STATE} -> mitmproxy"

check brew --version
if [ "$CHECK" == "FAILED" ]; then
	HAS_HOMEBREW=0
fi
echo -e "${STATE} -> Homebrew"

check nmap --version
if [ "$CHECK" == "FAILED" ]; then
	HAS_NMAP=0
fi
echo -e "${STATE} -> nmap"

# Install dependecies
if [ "$HAS_HOMEBREW" == 0 ]; then
	installHomebrew
fi

if [ "$HAS_MITMPROXY" == 0 ]; then
	installViaBrew mitmproxy
fi

if [ "$HAS_ARPOISON" == 0 ]; then
	installViaBrew arpoison
fi

if [ "$HAS_NMAP" == 0 ]; then
	installViaBrew nmap
fi

echo -e "${OK}All dependencies are installed"

