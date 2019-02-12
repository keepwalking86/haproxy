#!/bin/bash
#KeepWalking86
#Scripting for creat/renew a certificate with LetsEncrypt for HAProxy

CERTBOT=$(which certbot)
if [ $? -ne 0 ]; then
	echo "Certbot not installed. Please install the Certbot to get certs from LetsEncrypt"
	exit 1
fi

FORWARD_PORT=8888

# Directory contains keys and certificates
CERT_PATH=/etc/letsencrypt/live

# Check root account
if [ $UID -ne 0 ] ; then
        echo "Please, run this script as root account!"
        exit 1
fi

# Check argument for domain
if [ -z $1 ]; then
        echo "Please enter your domain to create certificate"
	echo "$0 your_domain"
        exit 1
fi

DOMAIN=$1

# Create/renew certificate
$CERTBOT certonly --standalone --http-01-port=${FORWARD_PORT} -d $DOMAIN --agree-tos --force-renewal

# Append private key & crt to pem
cat $CERT_PATH/$DOMAIN/{fullchain.pem,privkey.pem} > ${CERT_PATH}/${DOMAIN}/${DOMAIN}.pem

# Reload the haproxy daemon
systemctl reload haproxy
