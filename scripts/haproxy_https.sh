#!/bin/bash
#KeepWalking86
#Initial
IP_SERVER1=192.168.10.111
IP_SERVER2=192.168.10.112
IP_SERVER3=192.168.10.113

#Check root account
if [ $UID -ne 0 ] ; then
        echo "Please, run this script as root account!"
        exit 1
fi

#Check argument for domain
if [ -z $1 ]; then
        echo "Please enter your domain to configure load balancing"
	echo "$0 your_domain"
        exit 1
fi
DOMAIN=$1

# check the domain is valid!
PATTERN="^([[:alnum:]]([[:alnum:]\-]{0,61}[[:alnum:]])?\.)+[[:alpha:]]{2,6}$"
if [[ "$DOMAIN" =~ $PATTERN ]]; then
        DOMAIN=`echo $DOMAIN | tr '[A-Z]' '[a-z]'`
else
        echo "Invalid domain. Please enter your domain as example.com"
        exit 1
fi

#Replace dots with underscores
DOMAIN_ACL=`echo $DOMAIN | sed 's/\./_/g'`

echo "Setup LB HAProxy for $DOMAIN"
sleep 2

#Check pem for $DOMAIN
PEM_PATH=/etc/ssl/$DOMAIN/$DOMAIN.pem
if [ ! -f $PEM_PATH ]; then
        echo "Creating a self-signed certificate for $DOMAIN"
        sleep 2
        
        #Creating a self-signed certificate with OpenSSL
        #Inititial
        commonname=$DOMAIN
        country=VN
        state=HN
        locality=CG
        organization=$DOMAIN
        organizationalunit=IT
        email=keepwalking86@$DOMAIN

        #Generate a self-signed certificate
        echo "Generate a self-signed certificate for $DOMAIN"
        mkdir -p /etc/ssl/$DOMAIN && cd /etc/ssl/$DOMAIN
        openssl req -newkey rsa:4096 -nodes -sha256 -keyout $DOMAIN.key \
        -x509 -days 365 -out $DOMAIN.crt \
        -subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organizationalunit/CN=$commonname/emailAddress=$email"

        #Append private key & crt to pem
        bash -c "cat /etc/ssl/$DOMAIN/$DOMAIN.key /etc/ssl/$DOMAIN/$DOMAIN.crt >/etc/ssl/$DOMAIN/$DOMAIN.pem"
fi


#Create haproxy.cfg
echo "Creating haproxy configuration file"
sleep 2
cat >haproxy.cfg <<EOF
# Global settings
global
        pidfile     /var/run/haproxy.pid
        maxconn 100000
        user haproxy
        group haproxy
        daemon
        quiet
        stats socket /var/lib/haproxy/stats
        log 127.0.0.1   local0

# Proxies settings
## Defaults section
defaults
        log     global
        mode    http
        option  httplog
	option  forwardfor
        option  dontlognull
        retries 3
        option      redispatch
        maxconn     100000
        retries                 3
        timeout http-request    5s
        timeout queue           10s
        timeout connect         10s
        timeout client          10s
        timeout server          10s
        timeout http-keep-alive 10s
        timeout check           10s

## Frontend section
frontend http-in
        bind *:80
        acl ${DOMAIN_ACL}-acl hdr(host) -i $DOMAIN
        use_backend ${DOMAIN_ACL} if ${DOMAIN_ACL}-acl
## Backend section
backend ${DOMAIN_ACL}
        balance roundrobin
        server server1 $IP_SERVER1:8080 weight 1 check
        server server2 $IP_SERVER2:8080 weight 1 check
        server server3 $IP_SERVER3:8080 weight 1 check
## Statistics settings
listen statistics
        bind *:1986
        stats enable
	stats admin if TRUE
        stats hide-version
        stats realm Haproxy\ Statistics
        stats uri /stats
        stats refresh 30s
        stats auth keepwalking86:ILoveVietnam$
EOF
