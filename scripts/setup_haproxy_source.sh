#!/bin/bash
#Keepwalking86
#Script for installing Haproxy from source on CentOS/Ubuntu/Debian using Systemd

#Define variables
VERSION=1.8.18
#Text color variables
txtred=$(tput setaf 1)    # Red
txtgreen=$(tput setaf 2)  # Green
txtyellow=$(tput setaf 3) # Yellow
txtreset=$(tput sgr0)     # Text reset

## Installing prerequisite packages to compile
echo "${txtyellow}***Install prerequisite packages to compile***{txtreset}"
sleep 2
if [ -f /etc/debian_version ]; then
    sudo apt install make gcc perl pcre-devel zlib-devel libssl-dev
else
    if [ -f /etc/redhat-release ]; then
        yum -y install make gcc perl pcre-devel zlib-devel openssl-devel
    else "Distro hasn't been supported by this script"
    fi
fi

#Turning on Packet Forwarding and Nonlocal Binding
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
echo "net.ipv4.ip_nonlocal_bind = 1" >> /etc/sysctl.conf

#Download and extract the source code
cd /opt && curl -O https://www.haproxy.org/download/1.8/src/haproxy-${VERSION}.tar.gz
tar -zxvf haproxy-${VERSION}.tar.gz

#Compile the program
#linux2628 for Linux 2.6.28, 3.x, and above
cd /opt/haproxy-${VERSION}
make TARGET=linux2628 USE_OPENSSL=1

echo "${txtyellow}***Install HAProxy***{txtreset}"
sleep 3
make install

#Setup Haproxy
echo "${txtyellow}***Setup Haproxy***{txtreset}"
sleep 3

#Adding HAProxy user
useradd -s /usr/sbin/nologin -r haproxy

#Create soft link HAProxy binary to /usr/sbin/
ln -s /usr/local/sbin/haproxy /usr/sbin/

#Create directories and statistics file for HAProxy
mkdir -p /etc/haproxy
mkdir -p /var/lib/haproxy 
touch /var/lib/haproxy/stats

#Create haproxy configuration file
#Edit haproxy.conf after installation
curl -o /etc/haproxy/haproxy.cfg https://raw.githubusercontent.com/keepwalking86/haproxy/master/conf/haproxy_http.cfg

#Create Systemd service script
cat >/lib/systemd/system/haproxy.service<<EOF
[Unit]
Description=HAProxy Load Balancer
StartLimitInterval=0
StartLimitBurst=0
After=syslog.target network.target

[Service]
ExecStart=/usr/sbin/haproxy -W -f /etc/haproxy/haproxy.cfg -p /var/run/haproxy.pid
ExecReload=/usr/sbin/haproxy -f /etc/haproxy/haproxy.cfg -c -q
ExecReload=/bin/kill -USR2 \$MAINPID
KillMode=mixed
Type=forking

[Install]
WantedBy=multi-user.target
EOF

#Enable and start haproxy.service
systemctl enable haproxy.service
systemctl start haproxy.service