.SUFFIXES: .csr .pem .conf .crt .jks
.PRECIOUS: %/ca-key.pem %/ca-cert.pem %/cert-chain.pem
.PRECIOUS: %/workload-cert.pem %/key.pem %/workload-cert-chain.pem %/workload-cert.crt
.PRECIOUS: %/keystore.jks %/truststore.jks
.SECONDARY: root-cert.csr %/cluster-ca.csr %/keystore-tmp.jks

.DEFAULT_GOAL := help

ROOTCA_DAYS := 375
INTERMEDIATE_DAYS := 3600
WORKLOAD_DAYS := 375
STOREPASS := secret
ALIAS := bigbang.dev

#------------------------------------------------------------------------
##help:		print this help message
.PHONY: help

help:
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/##//'

#------------------------------------------------------------------------
##root-ca:	generate root CA files (key and certificate) in current directory.
.PHONY: root-ca

root-ca: root-key.pem root-cert.pem

root-cert.pem: root-cert.csr root-key.pem
	@echo "generating $@"
	@openssl x509 -req -sha256 -days $(ROOTCA_DAYS) -signkey root-key.pem \
		-extensions v3_ca -extfile root-ca.conf \
		-in root-cert.csr -out root-cert.pem

root-cert.csr: root-key.pem root-ca.conf
	@echo "generating $@"
	@openssl req -sha256 -new -key $< -config root-ca.conf -out $@

root-key.pem:
	@echo "generating $@"
	@openssl genrsa -out $@ 4096
#------------------------------------------------------------------------
##<name>-cacerts: generate self signed intermediate certificates for <name> and store them under <name> directory.
.PHONY: %-cacerts

%-cacerts: %/cert-chain.pem
	@echo "done"

%/cert-chain.pem: %/ca-cert.pem root-cert.pem
	@echo "generating $@"
	@cat $^ > $@
	@echo "Intermediate inputs stored in $(dir $<)"
	@cp root-cert.pem $(dir $<)

%/ca-cert.pem: %/cluster-ca.csr root-key.pem root-cert.pem
	@echo "generating $@"
	@openssl x509 -req -sha256 -days $(INTERMEDIATE_DAYS) \
		-CA root-cert.pem -CAkey root-key.pem -CAcreateserial\
		-extensions v3_intermediate_ca -extfile root-ca.conf \
		-in $< -out $@

%/cluster-ca.csr: %/ca-key.pem intermediate-ca.conf
	@echo "generating $@"
	@openssl req -sha256 -new -config intermediate-ca.conf -key $< -out $@

%/ca-key.pem:
	@echo "generating $@"
	@mkdir -p $(dir $@)
	@openssl genrsa -out $@ 4096

#------------------------------------------------------------------------
##<namespace>-certs: generate intermediate certificates and sign certificates for <namespace> and store them in <namespace> directory.
.PHONY: %-certs

%-certs: %/ca-cert.pem %/workload-cert-chain.pem %/workload-cert.crt root-cert.pem
	@echo "done"

%/workload-cert-chain.pem: %/workload-cert.pem %/ca-cert.pem root-cert.pem
	@echo "generating $@"
	@cat $^ > $@
	@echo "Intermediate and workload certs stored in $(dir $<)"
	@cp root-cert.pem $(dir $@)/root-cert.pem

%/workload-cert.crt: %/workload-cert.pem
	@echo "extracting public key to $@"
	@openssl x509 -pubkey -noout -in $< > $@

%/workload-cert.pem: %/workload.csr
	@echo "generating $@"
	@openssl x509 -sha256 -req -days $(WORKLOAD_DAYS) \
		-CA $(dir $<)/ca-cert.pem  -CAkey $(dir $<)/ca-key.pem -CAcreateserial\
		-extensions usr_cert -extfile intermediate-ca.conf \
		-in $< -out $@

%/workload.csr: %/key.pem intermediate-ca.conf
	@echo "generating $@"
	@openssl req -sha256 -new -config intermediate-ca.conf -key $< -out $@

%/key.pem:
	@echo "generating $@"
	@mkdir -p $(dir $@)
	@openssl genrsa -out $@ 2048

#------------------------------------------------------------------------
##<namespace>-jks: generate a keystore and truststore signed by an intermediate certificate in <namespace>
.PHONY: $-jks

%-jks: %/keystore.jks %/truststore.jks
	@echo "done"

%/keystore.jks: %/keystore.pem %/ca-cert.pem
	@echo "Adding signatures to keystore"
	@keytool -conf $(dir $<)/keystore.conf -keystore $@ -alias CARoot -importcert -file $(dir $<)/ca-cert.pem
	@keytool -conf $(dir $<)/keystore.conf -keystore $@ -alias $(ALIAS) -importcert -file $<
	@echo "CA and signed cert added to keystore"
	@echo "done"

%/keystore.conf:
	@echo "keytool.genkeypair = -dname 'cn=$(ALIAS),o=Defense Unicorns,c=US,L=Orlando,ST=Florida' -storepass $(STOREPASS)\n\
	keytool.all = -storepass $(STOREPASS)" > $@

%/keystore-tmp.jks: %/keystore.conf
	@echo "Generating keystore"
	@keytool -conf $< -keystore $@ -alias $(ALIAS) -keyalg RSA -genkey

%/keystore.csr: %/keystore-tmp.jks %/keystore.conf
	@echo "Exporting certificate -> $@"
	@keytool -conf $(dir $<)/keystore.conf -keystore $< -alias $(ALIAS) -certreq -file $@

%/truststore.jks: %/ca-cert.pem %/keystore.conf
	@echo "Creating trust store"
	@keytool -conf $(dir $<)/keystore.conf -keystore $@ -alias CARoot -importcert -file $<

%/keystore.pem: %/keystore.csr %/ca-cert.pem %/ca-key.pem
	@echo "Signing certificate"
	@openssl x509 -req -sha256 -days $(WORKLOAD_DAYS) \
		-CA $(dir $<)/ca-cert.pem -CAkey $(dir $<)/ca-key.pem \
		-CAcreateserial \
		-in $< -out $@
