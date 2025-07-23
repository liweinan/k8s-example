#!/bin/bash

set -e

# Generate a private key for the CA
openssl genrsa -out ca.key 2048

# Create a self-signed certificate for the CA
openssl req -new -x509 -key ca.key -out ca.crt -subj "/CN=webhook-ca"

# Generate a private key for the webhook server
openssl genrsa -out webhook.key 2048

# Create a certificate signing request (CSR) for the webhook server
openssl req -new -key webhook.key -out webhook.csr -subj "/CN=webhook-server.default.svc"

# Sign the CSR with the CA, creating the webhook server's certificate
openssl x509 -req -in webhook.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out webhook.crt

echo "Certificates generated successfully!"
