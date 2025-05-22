#!/bin/bash

FILE_NAME="replace_api_yaml_env_param.sh"
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

main() {
    local config_file="${CONFIG_FILES_DIR}/config.json"
    if [ ! -f "$config_file" ]; then
        echo "$INFO config.json not found!"
        update_stage_res "Replace_placeholders" "FAILED"
        exit 1
    fi
    local APIC_GATEWAY_URL=$(jq -r '.APIC_GATEWAY_URL' "$config_file")
    local isSuccess=1
    for ymlFile in ${WORKING_DIR_BASIC}/*.yaml; do
        [ -e "$ymlFile" ] || continue
        echo "$INFO Replacing placeholders in file: $(basename $ymlFile) ..."
        sed -i "s/PROVORG/${PROV_ORG_NAME}/g" "$ymlFile"
        sed -i "s/CATALOGNAME/${PROV_ORG_CATALOG_NAME}/g" "$ymlFile"
        sed -i "s#APIGWYBASEURL#${APIC_GATEWAY_URL}/${PROV_ORG_NAME}/${PROV_ORG_CATALOG_NAME}#g" "$ymlFile"
        if [ $? -ne 0 ]; then
            isSuccess=0
        fi
    done
    if [ $isSuccess -eq 1 ]; then
        update_stage_res "Replace_placeholders" "SUCCESS"
        echo "$INFO Replace_placeholders SUCCESS"
    else
        update_stage_res "Replace_placeholders" "FAILED"
        echo "$INFO Replace_placeholders FAILED"
        exit 1
    fi
}

main 