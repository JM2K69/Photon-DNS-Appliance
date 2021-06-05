#!/bin/bash -eux

##
## Misc configuration
##

echo '> Disable IPv6'
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf


echo '> Update photon-repos BaseURL...'
tdnf -y update photon-repos

echo '> Clean and makecache tdnf...'
tdnf clean all
tdnf makecache

#echo '> Applying latest Updates...'
#tdnf -y update


echo '> Installing Additional Packages...'
tdnf install -y \
  less \
  logrotate \
  wget \
  kbd \
  nano \
  unbound

echo '> Done'
