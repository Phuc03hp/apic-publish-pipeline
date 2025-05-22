#!/bin/bash

FILE_NAME="test_apic_apis.sh"
INFO="[${FILE_NAME}] - "
WORKING_DIR_BASIC="../WORKSPACE"
AUDIT_FILENAME="apic-pipeline-audit.json"

update_stage_res() {
    local stage_name="$1"
    local stage_res="$2"
    local audit_file="${WORKING_DIR_BASIC}/${AUDIT_FILENAME}"
    if [ ! -f "$audit_file" ]; then
        echo '{}' > "$audit_file"
    fi
    local current_json
    current_json=$(cat "$audit_file")
    updated_json=$(echo "$current_json" | jq --arg stage "$stage_name" --arg res "$stage_res" '.STAGE_SUMMARY[$stage] = {"Result": $res}')
    echo "$updated_json" > "$audit_file"
}

update_test_apis_audit() {
    local api_name="$1"
    local result="$2"
    local audit_file="${WORKING_DIR_BASIC}/${AUDIT_FILENAME}"
    if [ ! -f "$audit_file" ]; then
        echo '{}' > "$audit_file"
    fi
    local current_json
    current_json=$(cat "$audit_file")
    updated_json=$(echo "$current_json" | jq --arg key "$api_name" --arg val "$result" '.APIs[$key].Test_Result = $val')
    echo "$updated_json" > "$audit_file"
}

main() {
    local config_file="${CONFIG_FILES_DIR}/config.json"
    if [ ! -f "$config_file" ]; then
        echo "$INFO config.json not found!"
        update_stage_res "APIC_API_Test" "FAILED"
        exit 1
    fi
    local APIC_GATEWAY_URL=$(jq -r '.APIC_GATEWAY_URL' "$config_file")
    local isSuccess=1
    for api_file in ${WORKING_DIR_BASIC}/*.yaml; do
        [ -e "$api_file" ] || continue
        local basepath=$(yq e '.basePath' "$api_file" 2>/dev/null)
        [ "$basepath" == "null" ] && continue
        local apiname=$(basename "$api_file" .yaml)
        local url="${APIC_GATEWAY_URL}/${PROV_ORG_TITLE// /-}/${PROV_ORG_CATALOG_NAME}${basepath}/stub"
        url=$(echo "$url" | tr '[:upper:]' '[:lower:]')
        echo "$INFO Testing API: $apiname at $url"
        local status_code=$(curl -sk -o /dev/null -w "%{http_code}" -H "Content-Type: application/json" -H "Accept: application/json" "$url")
        update_test_apis_audit "$apiname" "$status_code"
        if [ "$status_code" != "200" ]; then
            isSuccess=0
        fi
    done
    if [ $isSuccess -eq 1 ]; then
        update_stage_res "APIC_API_Test" "SUCCESS"
        echo "$INFO APIC_API_Test SUCCESS"
    else
        update_stage_res "APIC_API_Test" "FAILED"
        echo "$INFO APIC_API_Test FAILED"
        exit 1
    fi
}

main 