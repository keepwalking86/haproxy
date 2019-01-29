#!/bin/bash
#Script for creating a self-signed certificate with OpenSSL
#keepwalking86

#Check root account
if [ $UID -ne 0 ] ; then
        echo "Please, run this script as root account!"
        exit 1
fi

#Check argument for domain
if [ -z $1 ]; then
        echo "Please enter your domain to create certificate"
	echo "$0 your_domain"
        exit 1
fi
DOMAIN=$1

#Check the domain is valid!
PATTERN="^([[:alnum:]]([[:alnum:]\-]{0,61}[[:alnum:]])?\.)+[[:alpha:]]{2,6}$"
if [[ "$DOMAIN" =~ $PATTERN ]]; then
        DOMAIN=`echo $DOMAIN | tr '[A-Z]' '[a-z]'`
else
        echo "Invalid domain. Please enter your domain as example.com"
        exit 1
fi

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
