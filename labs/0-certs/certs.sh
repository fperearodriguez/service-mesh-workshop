#!/bin/bash

CURRENT_DIR=$(pwd)

rm -f *.pem

echo "Create CA"
## generate rootca private key
openssl genrsa  -out $CURRENT_DIR/labs/0-certs/cakey.pem 4096

## generate rootCA certificate
openssl req -new -x509 -days 3650  -config $CURRENT_DIR/labs/0-certs/server.conf  -key $CURRENT_DIR/labs/0-certs/cakey.pem -out $CURRENT_DIR/labs/0-certs/ca.pem

## Verify the rootCA certificate content and X.509 extensions
openssl x509 -noout -text -in $CURRENT_DIR/labs/0-certs/ca.pem

echo "Client cert"
openssl genrsa -out $CURRENT_DIR/labs/0-certs/client.key 4096
openssl req -new -key $CURRENT_DIR/labs/0-certs/client.key -out $CURRENT_DIR/labs/0-certs/client.csr -config $CURRENT_DIR/labs/0-certs/client.conf -extensions req_ext
openssl x509 -req -in $CURRENT_DIR/labs/0-certs/client.csr -CA $CURRENT_DIR/labs/0-certs/ca.pem -CAkey $CURRENT_DIR/labs/0-certs/cakey.pem -out $CURRENT_DIR/labs/0-certs/client.pem -CAcreateserial -days 365 -sha256 -extfile $CURRENT_DIR/labs/0-certs/client.conf -extensions req_ext

echo "Server cert"
openssl genrsa -out $CURRENT_DIR/labs/0-certs/server.key 4096
openssl req -new -key $CURRENT_DIR/labs/0-certs/server.key -out $CURRENT_DIR/labs/0-certs/server.csr -config $CURRENT_DIR/labs/0-certs/server.conf -extensions req_ext
openssl x509 -req -in $CURRENT_DIR/labs/0-certs/server.csr -CA $CURRENT_DIR/labs/0-certs/ca.pem -CAkey $CURRENT_DIR/labs/0-certs/cakey.pem -out $CURRENT_DIR/labs/0-certs/server.pem -CAcreateserial -days 365 -sha256 -extfile $CURRENT_DIR/labs/0-certs/server.conf -extensions req_ext