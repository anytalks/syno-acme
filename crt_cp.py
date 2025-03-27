#!/usr/bin/env python3

# This script copies cert recorded in INFO file from src to des.

import json
import sys
import shutil
import os

CERT_FILES = [
    'cert.pem',
    'privkey.pem',
    'fullchain.pem'
]

SRC_DIR_NAME = sys.argv[1]

CERT_BASE_PATH = '/usr/syno/etc/certificate'
PKG_CERT_BASE_PATH = '/usr/local/etc/certificate'

ARCHIEV_PATH = CERT_BASE_PATH + '/_archive'
INFO_FILE_PATH = ARCHIEV_PATH + '/INFO'

services = []
try:
    with open(INFO_FILE_PATH, 'r') as f:
        info = json.load(f)
    services = info[SRC_DIR_NAME]['services']
except Exception as e:
    print('[ERR] load INFO file - %s fail: %s' % (INFO_FILE_PATH, str(e)))
    sys.exit(1)

CP_FROM_DIR = os.path.join(ARCHIEV_PATH, SRC_DIR_NAME)
for service in services:
    print('Copy cert for %s' % (service['display_name']))
    if service['isPkg']:
        CP_TO_DIR = os.path.join(PKG_CERT_BASE_PATH, service['subscriber'], service['service'])
    else:
        CP_TO_DIR = os.path.join(CERT_BASE_PATH, service['subscriber'], service['service'])
    
    for f in CERT_FILES:
        src = os.path.join(CP_FROM_DIR, f)
        des = os.path.join(CP_TO_DIR, f)
        try:
            shutil.copy2(src, des)
        except Exception as e:
            print('[WRN] copy from %s to %s fail: %s' % (src, des, str(e)))
