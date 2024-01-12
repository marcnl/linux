#!/bin/sh

# Execute: ./cert.sh <fqdn> <ipaddress>

mkdir -p ./cert_$1/CAs && cd ./cert_$1
cat <<EOF >> ./openssl_$1.conf
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = VA
L = Somewhere
O = MyOrg
OU = MyOU
CN = $1

[v3_req]
subjectAltName = @alt_names

[alt_names]
IP.1 = $2
DNS.1 = $1
EOF

openssl ecparam -genkey -name prime256v1 | openssl ec -out ./private.key
openssl req -new -x509 -nodes -days 730 -key private.key -out ./public.crt -config ./openssl_$1.conf
cp ./public.crt ./CAs/
#rm ./openssl_$1.conf
cd ..
exit
