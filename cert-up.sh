#!/bin/bash

# path of this script
BASE_ROOT=$(cd "$(dirname "$0")";pwd)
# date time
DATE_TIME=`date +%Y%m%d%H%M%S`
# base crt path
CRT_BASE_PATH="/usr/syno/etc/certificate"
PKG_CRT_BASE_PATH="/usr/local/etc/certificate"
#CRT_BASE_PATH="/Users/carl/Downloads/certificate"
ACME_BIN_PATH=${BASE_ROOT}/acme.sh
TEMP_PATH=${BASE_ROOT}/temp
CRT_PATH_NAME=`cat ${CRT_BASE_PATH}/_archive/DEFAULT`
CRT_PATH=${CRT_BASE_PATH}/_archive/${CRT_PATH_NAME}

backupCrt () {
  echo 'begin backupCrt'
  BACKUP_PATH=${BASE_ROOT}/backup/${DATE_TIME}
  mkdir -p ${BACKUP_PATH}
  cp -r ${CRT_BASE_PATH} ${BACKUP_PATH}
  cp -r ${PKG_CRT_BASE_PATH} ${BACKUP_PATH}/package_cert
  echo ${BACKUP_PATH} > ${BASE_ROOT}/backup/latest
  echo 'done backupCrt'
  return 0
}

installAcme () {
  echo 'begin installAcme'
  mkdir -p ${TEMP_PATH}
  cd ${TEMP_PATH}
  echo 'begin downloading acme.sh tool...'
  wget --no-check-certificate -O acme.sh https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh
  chmod +x acme.sh
  echo 'begin installing acme.sh tool...'
  ./acme.sh --install --nocron --home ${ACME_BIN_PATH}
  echo 'done installAcme'
  rm -rf ${TEMP_PATH}
  return 0
}

generateCrt () {
  echo 'begin generateCrt'
  cd ${BASE_ROOT}
  source config
  echo 'begin updating default cert by acme.sh tool'
  source ${ACME_BIN_PATH}/acme.sh.env
  ${ACME_BIN_PATH}/acme.sh --force --log --server letsencrypt --issue --dns ${DNS} --dnssleep ${DNS_SLEEP} -d "${DOMAIN}" -d "*.${DOMAIN}"
  ${ACME_BIN_PATH}/acme.sh --installcert -d ${DOMAIN} -d *.${DOMAIN} \
    --certpath ${CRT_PATH}/cert.pem \
    --key-file ${CRT_PATH}/privkey.pem \
    --fullchain-file ${CRT_PATH}/fullchain.pem

  if [ -s "${CRT_PATH}/cert.pem" ]; then
    echo 'done generateCrt'
    return 0
  else
    echo '[ERR] fail to generateCrt'
    echo "begin revert"
    revertCrt
    exit 1;
  fi
}

updateService () {
  echo 'begin updateService'
  echo 'cp cert path to des'
  python3 ${BASE_ROOT}/crt_cp.py ${CRT_PATH_NAME}
  echo 'done updateService'
}


reloadWebService () {
  echo 'begin reloadWebService'
  
  if systemctl list-units --type=service | grep -q nginx; then
    echo 'Restarting Nginx...'
    systemctl restart nginx
  else
    echo '[WARN] Nginx service not found, skipping restart.'
  fi

  echo 'done reloadWebService'
}

revertCrt () {
  echo 'begin revertCrt'
  BACKUP_PATH=${BASE_ROOT}/backup/$1
  if [ -z "$1" ]; then
    BACKUP_PATH=`cat ${BASE_ROOT}/backup/latest`
  fi
  if [ ! -d "${BACKUP_PATH}" ]; then
    echo "[ERR] backup path: ${BACKUP_PATH} not found."
    return 1
  fi
  echo "${BACKUP_PATH}/certificate ${CRT_BASE_PATH}"
  cp -rf ${BACKUP_PATH}/certificate/* ${CRT_BASE_PATH}
  echo "${BACKUP_PATH}/package_cert ${PKG_CRT_BASE_PATH}"
  cp -rf ${BACKUP_PATH}/package_cert/* ${PKG_CRT_BASE_PATH}
  reloadWebService
  echo 'done revertCrt'
}

updateCrt () {
  echo '------ begin updateCrt ------'
  backupCrt
  installAcme
  generateCrt
  updateService
  reloadWebService
  echo '------ end updateCrt ------'
}

case "$1" in
  update)
    echo "begin update cert"
    updateCrt
    ;;

  revert)
    echo "begin revert"
      revertCrt $2
      ;;

    *)
        echo "Usage: $0 {update|revert}"
        exit 1
esac
