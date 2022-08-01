#!/bin/bash

# Filename      : setup_user_containers.sh
# Function      : Set up user containers using LXC.
#
# Copyright (C) 2020  A. James Lewis
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

#
# User Config
#
SUBID=$((100000*UID))
#

#
# Functions
#
checkpackage () {
 UPDATE=0
 RELOG=0
 for i in "$@"
 do
  printf "${CYAN}"
  echo -n "Checking for installed package, $i - "
  if dpkg -l "$i" | grep -q "^ii" 1> /dev/null 2> /dev/null; then
   echo "Found!"
  else
   echo "Not Found."
   echo 
   echo "Attempting install packages"
   echo
   printf "${WHITE}"
   if [ ${UPDATE} -eq 0 ]; then
    if [ "x${MODE}" == "xunprivilaged" ]; then
     sudocheck
     sudo apt update
    else
     apt update
    fi    
    UPDATE=1
   fi
   [ "x${i}" == "xlxc" ]&&RELOG=1
   if [ "x${MODE}" == "xunprivilaged" ]; then
    sudo apt -y install $i
   else
    apt -y install $i
   fi
   if [ $? -ne 0 ]; then
    printf "${CYAN}"
    echo "Error Installing, Aborted!"
    return 1
   fi
  fi
 done
echo 
[ -f /var/run/reboot-required ]&&REBOOT=1
return 0   
}

sudocheck () {
 if ! sudo -V 1> /dev/null 2> /dev/null; then
  printf "${CYAN}Sorry, we need to use sudo to complete the script, but it is not found. Aborted!${WHITE}\n"
  exit 1
  return 1
 else
  return 0
 fi
}

useraction () {
 printf "${CYAN}"
 if [ ${REBOOT} -eq 0 ]&&[ ${RELOG} -eq 1 ]; then
  echo "We installed some components which likely require that you log out"
  echo "and back in before trying to use LXC containers."
  echo
  echo "Please do this before trying to use unprivilaged LXC containers."
  echo
  printf "${WHITE}"
 elif [ ${REBOOT} -eq 1 ]; then
  echo "We installed some components or applied configuration which require"
  echo "that you REBOOT before trying to use LXC containers."
  echo
  echo "Please reboot before trying to use unprivilaged LXC containers."
  echo
  printf "${WHITE}"
 fi
}


#
# Setup & Arguments
#
REQUIRED="lxc uidmap bridge-utils debootstrap dnsmasq-base gnupg iproute2 iptables lxc-templates lxcfs openssl rsync acl"
SCRIPT=$(basename "$0")
SCRIPTPATH=$(dirname "$0")
SUBIDS="${SUBID}-$((${SUBID}+65536))"
REBOOT=0
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
TITLE='\033[0;37;1m'
WHITE='\033[0;m'
YES=0
#
while true; do
 if [ ! $1 ]; then
  break
 fi
 case "$1" in
  --yes)
   YES=1
   ;;
  *)
   echo "Usage: $0 [--yes]"
   exit 1
   ;;
 esac  
 shift
done
#
MODE="unprivilaged"
if [ "x$(id -u)" == "x0" ]; then
 MODE="standard"
fi
#
if [[ $MODE == "standard" ]]; then
 printf "${RED}Must be run as a non-root user${WHITE}"
 exit 1
fi
#
printf "${TITLE}Setting up LXC container environment.${CYAN}\n"
echo
if [ ! -f /etc/debian_version ]; then
 echo "Sorry, this script requires a debian/ubuntu based distribution. Aborted!"
 echo
 printf "${WHITE}"
 exit 1
fi
#
if checkpackage ${REQUIRED}; then
 printf "${CYAN}"
 echo "All Components found, continueing."
 echo
else
 echo "Components missing, cannot continue."
 echo
 printf "${WHITE}"
 exit 1
fi
#


#
# Configure unprivilaged LXC containers.
#
if [ "x${MODE}" == "xunprivilaged" ]; then
 if [ "x$(lsb_release -si)" == "xDebian" ]; then
  sudocheck
  if [ $(cat /proc/sys/kernel/unprivileged_userns_clone) -eq 0 ]; then
   printf "${CYAN}Writing To /etc/sysctl.d/00-local-userns.conf${WHITE}\n"
   echo "kernel.unprivileged_userns_clone = 1" | sudo tee /etc/sysctl.d/00-local-userns.conf
   echo 1 | sudo tee /proc/sys/kernel/unprivileged_userns_clone > /dev/null
  fi
 fi
#
 if [ ! -d "${HOME}" ]; then
  printf "${CYAN}"
  echo "\$HOME appears to be invalid, Aborting!"
  echo
  printf "${WHITE}"
  exit 1
 fi
#
 if [ ! -d "${HOME}/.config/lxc" ]; then
  printf "${CYAN}"
  echo "Can't find existing unprivileged container setup"
  echo "this will add subuid/gids ${SUBIDS} to your account"
  echo "if you are using these id's elsewhere, please abort the script"
  echo "in this case, also check ${HOME}/.config/lxc/default.conf"
  echo
  if [ ${YES} -eq 0 ]; then
   echo "Press ENTER to configure, or ^C to abort"
   read i
   echo
  fi
  echo "Setting up unprivileged LXC containers"
  echo
  printf "${WHITE}"
  sudocheck
  sudo usermod --add-subuids ${SUBIDS} $(whoami)
  sudo usermod --add-subgids ${SUBIDS} $(whoami)
#
  if [ ! -f /etc/default/lxc-net ]; then
   cat <<EOF > /tmp/lxc-net.$$
USE_LXC_BRIDGE="true"
LXC_BRIDGE="lxcbr0"
LXC_ADDR="10.128.7.1"
LXC_NETMASK="255.255.255.0"
LXC_NETWORK="10.128.7.0/24"
LXC_DHCP_RANGE="10.128.7.2,10.128.7.254"
LXC_DHCP_MAX="253"
LXC_DHCP_CONFILE=""
LXC_DOMAIN=""
EOF
   sudo systemctl enable lxc-net
   sudo systemctl start lxc-net
#
   sudo cp /etc/lxc/default.conf /etc/lxc/default.conf.backup
   sudo cp /tmp/lxc-net.$$ /etc/default/lxc-net
   rm /tmp/lxc-net.$$
   sudo sed -i "/^lxc.net.0/d" /etc/lxc/default.conf
   cp /etc/lxc/default.conf /tmp/default.conf.$$
   cat <<EOF >> /tmp/default.conf.$$
lxc.net.0.type = veth
lxc.net.0.link = lxcbr0
lxc.net.0.flags = up
lxc.net.0.hwaddr = 00:16:3e:xx:xx:xx
EOF
   sudo cp /tmp/default.conf.$$ /etc/lxc/default.conf
   rm /tmp/default.conf.$$
   REBOOT=1
  fi
#
  mkdir -p "${HOME}/.config"
  mkdir -p "${HOME}/.local/share/lxc"
  mkdir -p "${HOME}/.cache/lxc" 
  setfacl -m u:${SUBID}:x "${HOME}"
  setfacl -m u:${SUBID}:x "${HOME}/.local"
  setfacl -m u:${SUBID}:x "${HOME}/.local/share"
  setfacl -m u:${SUBID}:x "${HOME}/.local/share/lxc"
  cp -dpR /etc/lxc/ "${HOME}/.config"
  printf "${CYAN}"
  echo "lxc.idmap = u 0 ${SUBID} 65536" >> "${HOME}/.config/lxc/default.conf"
  echo "lxc.idmap = g 0 ${SUBID} 65536" >> "${HOME}/.config/lxc/default.conf"
#  sed -i "s,lxc.apparmor.profile = generated,lxc.apparmor.profile = lxc-container-default-cgns,g" "${HOME}/.config/lxc/default.conf"
  sed -i "s,^lxc.apparmor.profile.*,lxc.apparmor.profile = unconfined,g" "${HOME}/.config/lxc/default.conf"
  echo -n "Updating /etc/lxc/lxc-usernet, adding - "
  sudo sed -i "/^$(whoami)/d" /etc/lxc/lxc-usernet
  echo "$(whoami) veth lxcbr0 10" | sudo tee -a /etc/lxc/lxc-usernet
  echo
  useraction
 else
  echo "Looks like unprivileged LXC containers are already set up!"
  echo "If containers fail to work, you will need to fix it yourself!"
  echo
 fi
fi
