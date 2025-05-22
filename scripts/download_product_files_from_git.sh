#!/bin/bash

FILE_NAME="download_product_files_from_git.sh"
INFO="[${FILE_NAME}] - "
WORKING_DIR_BASIC="../WORKSPACE"
AUDIT_FILENAME="apic-pipeline-audit.json"

# Hàm ghi trạng thái vào file audit
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

update_product_download_audit() {
    local product_name="$1"
    local result="$2"
    local audit_file="${WORKING_DIR_BASIC}/${AUDIT_FILENAME}"
    if [ ! -f "$audit_file" ]; then
        echo '{}' > "$audit_file"
    fi
    local current_json
    current_json=$(cat "$audit_file")
    updated_json=$(echo "$current_json" | jq --arg key "$product_name" --arg val "$result" '.Products[$key].Download_Yaml_From_Git = $val')
    echo "$updated_json" > "$audit_file"
}

main() {
    local url="${GIT_PRODUCTS_APIS_URL//github/api.github}repos/${GIT_PRODUCTS_PATH}/contents?ref=${GIT_PRODUCTS_APIS_BRANCH}"
    local curl_auth_header="Authorization: token ${GIT_PRIV_TOKEN}"
    echo "$INFO Getting all Product names from: $url"
    local response=$(curl -s -H "$curl_auth_header" "$url")
    local product_names=($(echo "$response" | jq -r '.[] | select(.name | endswith(".yaml")) | .name'))
    echo "$INFO Product files to be downloaded: ${product_names[*]}"
    local isSuccess=1
    for filename in "${product_names[@]}"; do
        echo "$INFO Downloading file: $filename ..."
        local raw_url="${GIT_PRODUCTS_APIS_URL//github/raw.githubusercontent}${GIT_PRODUCTS_APIS_BRANCH}/${GIT_PRODUCTS_PATH}/$filename"
        curl -s -H "$curl_auth_header" -L "$raw_url" -o "${WORKING_DIR_BASIC}/$filename"
        if [ $? -eq 0 ] && [ -s "${WORKING_DIR_BASIC}/$filename" ]; then
            update_product_download_audit "${filename%.yaml}" "SUCCESS"
        else
            update_product_download_audit "${filename%.yaml}" "FAILED"
            isSuccess=0
        fi
    done
    if [ $isSuccess -eq 1 ]; then
        update_stage_res "Product_Download" "SUCCESS"
        echo "$INFO Product_Download SUCCESS"
    else
        update_stage_res "Product_Download" "FAILED"
        echo "$INFO Product_Download FAILED"
        exit 1
    fi
}

main 