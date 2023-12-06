# certs
Repo for creating self-signed certificates

###Target explanations:
root-ca: Makes a self-signed root CA files
<name>-cacerts: Creates self-signed intermedate certificates for <name>
<name>-certs: Creates a user type certificate for <name>

### Configuration:
The defaults in root-ca.conf and intermediate-ca.conf can and should be modified to suit your needs.

### Usage:
To make root CA certs: `make -f Makefile.selfsigned.mk root-ca`
To make intermediate CA certs: `make -f Makefile.selfsigned.mk cluster1-cacerts`.  This will store the certificates in `cluster1/` directory.
To make user CA certs: `make -f Makefile.selfsigned.mk cluster1-certs`.  This will also make cluster1-cacerts if they haven't already been made.
