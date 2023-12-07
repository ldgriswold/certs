# certs
Repo for creating self-signed certificates

### Target explanations:
root-ca: Makes a self-signed root CA files
<name>-cacerts: Creates self-signed intermedate certificates for <name>
<name>-certs: Creates a user type certificate for <name>

### Configuration:
The defaults in root-ca.conf and intermediate-ca.conf can and should be modified to suit your needs. If you are making a keystore.jks / truststore.jks pair, please look at the Makefile to modify how the configuration file is made (target %/keystore.conf).

### Usage:
* To make root CA certs: `make -f Makefile.selfsigned.mk root-ca`
* To make intermediate CA certs: `make -f Makefile.selfsigned.mk <name>-cacerts`.  This will store the certificates in `./<name>/` directory. Uses `intermediate-ca.conf` and `v3_intermediate_ca` as default
* To make user CA certs: `make -f Makefile.selfsigned.mk <name>-certs`. Uses `intermediate-ca.conf` and `usr_cert` as default
* To make a keystore/trustore.jks: `make -f Makefile.selfsigned.mk cluster1-jks`. Uses `intermediate-ca.conf` and `usr_cert` as default