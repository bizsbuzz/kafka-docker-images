#!/bin/bash

set -o nounset \
    -o errexit \
    -o verbose \
    -o xtrace

# Generate CA key
openssl req -new -x509 -keyout kafka-ca.key -out kafka-ca.crt -days 365 -subj '/CN=KafkaROOTCA/OU=INFRA/O=INFOR/L=NY/S=NY/C=US' -passin pass:infrak -passout pass:infrak


cp kafka-ca.crt kafka-ca.pem

# Kafkacat
openssl genrsa -des3 -passout "pass:infrak" -out kafkacat.client.key 1024
openssl req -passin "pass:infrak" -passout "pass:infrak" -key kafkacat.client.key -new -out kafkacat.client.req -subj '/CN=kafkacat.ec2.internal/OU=INFRA/O=INFOR/L=NY/S=NY/C=US'
openssl x509 -req -CA kafka-ca.crt -CAkey kafka-ca.key -in kafkacat.client.req -out kafkacat-ca1-signed.pem -days 9999 -CAcreateserial -passin "pass:infrak"



for i in broker1 broker2 broker3 client
do
        echo $i
        # Create keystores
        keytool -genkeypair -noprompt \
                                 -alias $i \
                                 -dname "CN=*.ec2.internal, OU=INFRA, O=INFOR, L=NY, S=NY, C=US" \
                                 -keystore kafka.$i.keystore.jks \
                                 -keyalg RSA \
                                 -storepass infrak \
                                 -keypass infrak

        # Create CSR, sign the key and import back into keystore
        keytool -keystore kafka.$i.keystore.jks -alias $i -certreq -file $i.csr -storepass infrak -keypass infrak

        openssl x509 -req -CA kafka-ca.crt -CAkey kafka-ca.key -in $i.csr -out $i-ca1-signed.crt -days 9999 -CAcreateserial -passin pass:infrak

        keytool -keystore kafka.$i.keystore.jks -alias CARoot -import -file kafka-ca.crt -storepass infrak -keypass infrak

        keytool -keystore kafka.$i.keystore.jks -alias $i -import -file $i-ca1-signed.crt -storepass infrak -keypass infrak

        # Create truststore and import the CA cert.
        keytool -keystore kafka.$i.truststore.jks -alias CARoot -import -file kafka-ca.crt -storepass infrak -keypass infrak

  echo "infrak" > ${i}_sslkey_creds
  echo "infrak" > ${i}_keystore_creds
  echo "infrak" > ${i}_truststore_creds
done

#Producer certs in different format
keytool -importkeystore -srckeystore kafka.client.keystore.jks -destkeystore kafka.client.keystore.p12 -srcstoretype JKS -deststoretype PKCS12 -srcstorepass infrak -deststorepass infrak -srckeypass infrak -destkeypass infrak -alias client -noprompt
openssl pkcs12 -in kafka.client.keystore.p12  -nokeys -out client.pem -passin "pass:infrak"
openssl pkcs12 -in kafka.client.keystore.p12  -nodes -nocerts -out client_key.pem -passin "pass:infrak"
