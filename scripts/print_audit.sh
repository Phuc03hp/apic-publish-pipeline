#!/bin/bash

FILE_NAME="print_audit.sh"
INFO="[${FILE_NAME}] - "
WORKING_DIR_BASIC="../WORKSPACE"
AUDIT_FILENAME="apic-pipeline-audit.json"

audit_file="${WORKING_DIR_BASIC}/${AUDIT_FILENAME}"
if [ ! -f "$audit_file" ]; then
    echo "$INFO Audit file not found!"
    exit 1
fi

echo "$INFO AUDIT"
echo "$INFO -----"
jq . "$audit_file" 