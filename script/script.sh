set -x
set -e

OUTPUT_FOLDER="${OUTPUT_FOLDER:-./}"
CONFIG_FILE="${CONFIG_FILE:-./config}"
export OUTPUT_FOLDER=$OUTPUT_FOLDER

## export values from config file
set -o allexport
source $CONFIG_FILE
set +o allexport

mkdir -p ${OUTPUT_FOLDER}
echo -n "" > ${OUTPUT_FOLDER}index.txt
echo -n "01" > ${OUTPUT_FOLDER}serial

mkdir -p ${OUTPUT_FOLDER}ca/private
mkdir -p ${OUTPUT_FOLDER}ca/csr
mkdir -p ${OUTPUT_FOLDER}ca/certs
openssl genrsa -out ${OUTPUT_FOLDER}ca/private/cakey.pem 4096
## Create CA Request
openssl req -new -x509 -set_serial 01 -days 3650 -config ./openssl.cnf -extensions v3_ca \
  -key ${OUTPUT_FOLDER}ca/private/cakey.pem -out ${OUTPUT_FOLDER}ca/csr/cacert.pem -subj "/C=DE/ST=Berlin/L=Berlin/O=FIWARE CA/CN=FIWARE-CA/emailAddress=ca@fiware.org/serialNumber=01"
## Convert x509 CA cert
openssl x509 -in ${OUTPUT_FOLDER}ca/csr/cacert.pem -out ${OUTPUT_FOLDER}ca/certs/cacert.pem -outform PEM
## Verify CA Cert
openssl x509 -noout -text -in ${OUTPUT_FOLDER}ca/certs/cacert.pem

# Intermediate
mkdir -p ${OUTPUT_FOLDER}intermediate/private
mkdir -p ${OUTPUT_FOLDER}intermediate/csr
mkdir -p ${OUTPUT_FOLDER}intermediate/certs

openssl genrsa -out ${OUTPUT_FOLDER}intermediate/private/intermediate.cakey.pem 4096
openssl req -new -sha256 -set_serial 02 -config ./openssl-intermediate.cnf \
  -subj "/C=DE/ST=Berlin/L=Berlin/O=FIWARE CA/CN=FIWARE-CA/emailAddress=ca@fiware.org/serialNumber=02" \
  -key ${OUTPUT_FOLDER}intermediate/private/intermediate.cakey.pem \
  -out ${OUTPUT_FOLDER}intermediate/csr/intermediate.csr.pem

openssl ca -config openssl.cnf -extensions v3_intermediate_ca -days 2650 -notext \
  -batch -in ${OUTPUT_FOLDER}intermediate/csr/intermediate.csr.pem \
  -out ${OUTPUT_FOLDER}intermediate/certs/intermediate.cacert.pem

openssl x509 -in ${OUTPUT_FOLDER}intermediate/certs/intermediate.cacert.pem -out ${OUTPUT_FOLDER}intermediate/certs/intermediate.cacert.pem -outform PEM

openssl x509 -noout -text -in ${OUTPUT_FOLDER}intermediate/certs/intermediate.cacert.pem

cat ${OUTPUT_FOLDER}intermediate/certs/intermediate.cacert.pem ${OUTPUT_FOLDER}ca/certs/cacert.pem > ${OUTPUT_FOLDER}intermediate/certs/ca-chain-bundle.cert.pem
openssl verify -CAfile ${OUTPUT_FOLDER}ca/certs/cacert.pem ${OUTPUT_FOLDER}intermediate/certs/ca-chain-bundle.cert.pem


# Client
mkdir -p ${OUTPUT_FOLDER}client/private
mkdir -p ${OUTPUT_FOLDER}client/csr
mkdir -p ${OUTPUT_FOLDER}client/certs

openssl genrsa -out ${OUTPUT_FOLDER}client/private/client.key.pem 4096
openssl req -new -set_serial 03 -key ${OUTPUT_FOLDER}client/private/client.key.pem -out ${OUTPUT_FOLDER}client/csr/client.csr \
  -subj "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORGANISATION/CN=$COMMON_NAME/emailAddress=$EMAIL/serialNumber=03/organizationIdentifier=$ORGANISATION_IDENTIFIER" \
  -config ./openssl-client.cnf
openssl x509 -req -in ${OUTPUT_FOLDER}client/csr/client.csr -CA ${OUTPUT_FOLDER}intermediate/certs/ca-chain-bundle.cert.pem \
  -CAkey ${OUTPUT_FOLDER}intermediate/private/intermediate.cakey.pem -out ${OUTPUT_FOLDER}client/certs/client.cert.pem \
  -CAcreateserial -days 1825 -sha256 -extfile ./openssl-client.cnf \
  -copy_extensions=copyall

openssl x509 -in ${OUTPUT_FOLDER}client/certs/client.cert.pem -out ${OUTPUT_FOLDER}client/certs/client.cert.pem -outform PEM

## Verify
openssl rsa -noout -text -in ${OUTPUT_FOLDER}client/private/client.key.pem
openssl req -noout -text -in ${OUTPUT_FOLDER}client/csr/client.csr
openssl x509 -noout -text -in ${OUTPUT_FOLDER}client/certs/client.cert.pem