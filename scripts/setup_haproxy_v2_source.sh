#!/bin/bash
#Keepwalking86
#Script for installing Haproxy from source on CentOS/Ubuntu/Debian using Systemd

#Define variables
HAPROXY_VERSION=2.0
VERSION=2.0.22
#Text color variables
txtred=$(tput setaf 1)    # Red
txtgreen=$(tput setaf 2)  # Green
txtyellow=$(tput setaf 3) # Yellow
txtreset=$(tput sgr0)     # Text reset

## Installing prerequisite packages to compile
echo "${txtyellow}***Install prerequisite packages to compile***{txtreset}"
sleep 2
if [ -f /etc/debian_version ]; then
    sudo apt-get update
    sudo apt-get install build-essential pcre-devel zlib-devel libssl-dev libssl-dev -y
else
    if [ -f /etc/redhat-release ]; then
        yum -y install make gcc perl pcre-devel zlib-devel openssl-devel
    else 
        echo "Distro has not been supported by this script"
        exit 1
    fi
fi

#Turning on Packet Forwarding and Nonlocal Binding
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
echo "net.ipv4.ip_nonlocal_bind = 1" >> /etc/sysctl.conf

#Download and extract the source code
cd /opt && curl -O https://www.haproxy.org/download/${HAPROXY_VERSION}/src/haproxy-${VERSION}.tar.gz
tar -zxvf haproxy-${VERSION}.tar.gz

#Compile the program
#linux2628 for Linux 2.6.28, 3.x, and above
#Target 'linux2628' was removed from HAProxy 2.0 due to being irrelevant and often wrong.
#Please use 'linux-glibc' instead or define your custom target
#by checking available options using 'make help TARGET=<your-target>'.
cd /opt/haproxy-${VERSION}
make TARGET=linux-glibc USE_OPENSSL=1

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
[[ ! -d /etc/sysconfig ]] && mkdir -p /etc/sysconfig
cat >/etc/sysconfig/haproxy<<EOF
OPTIONS="-x /var/lib/haproxy/stats"
EOF

cat >/etc/systemd/system/haproxy.service<<EOF
[Unit]
Description=HAProxy Load Balancer
After=network.target

[Service]
EnvironmentFile=/etc/sysconfig/haproxy
ExecStartPre=/usr/sbin/haproxy -f /etc/haproxy/haproxy.cfg -c -q
ExecStart=/usr/sbin/haproxy -W -f /etc/haproxy/haproxy.cfg -p /var/run/haproxy.pid
ExecReload=/usr/sbin/haproxy -f /etc/haproxy/haproxy.cfg -c -q \$OPTIONS
ExecReload=/bin/kill -USR2 \$MAINPID
KillMode=mixed
Type=forking
Restart=always

[Install]
WantedBy=multi-user.target
EOF

#Enable and start haproxy.service
systemctl enable haproxy.service
systemctl start haproxy.service
