#!/bin/bash

FILE_NAME="download_api_files_from_git.sh"
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

update_api_download_audit() {
    local api_name="$1"
    local result="$2"
    local audit_file="${WORKING_DIR_BASIC}/${AUDIT_FILENAME}"
    if [ ! -f "$audit_file" ]; then
        echo '{}' > "$audit_file"
    fi
    local current_json
    current_json=$(cat "$audit_file")
    updated_json=$(echo "$current_json" | jq --arg key "$api_name" --arg val "$result" '.APIs[$key].Download_Yaml_From_Git = $val')
    echo "$updated_json" > "$audit_file"
}

main() {
    local isSuccess=1
    local product_files=( $(ls ${WORKING_DIR_BASIC}/*.yaml 2>/dev/null) )
    local api_list=()
    for product_file in "${product_files[@]}"; do
        local apis=( $(yq e '.apis[].name' "$product_file" 2>/dev/null | sed 's/:/_/g') )
        for api in "${apis[@]}"; do
            api_list+=("$api")
        done
    done
    echo "$INFO APIs to download: ${api_list[*]}"
    for api_file in "${api_list[@]}"; do
        echo "$INFO Downloading file: $api_file.yaml ..."
        local raw_url="${GIT_PRODUCTS_APIS_URL//github/raw.githubusercontent}${GIT_PRODUCTS_APIS_BRANCH}/${GIT_APIS_PATH}/$api_file.yaml"
        curl -s -H "Authorization: token ${GIT_PRIV_TOKEN}" -L "$raw_url" -o "${WORKING_DIR_BASIC}/$api_file.yaml"
        if [ $? -eq 0 ] && [ -s "${WORKING_DIR_BASIC}/$api_file.yaml" ]; then
            update_api_download_audit "$api_file" "SUCCESS"
        else
            update_api_download_audit "$api_file" "FAILED"
            isSuccess=0
        fi
    done
    if [ $isSuccess -eq 1 ]; then
        update_stage_res "API_Download" "SUCCESS"
        echo "$INFO API_Download SUCCESS"
    else
        update_stage_res "API_Download" "FAILED"
        echo "$INFO API_Download FAILED"
        exit 1
    fi
}

main 