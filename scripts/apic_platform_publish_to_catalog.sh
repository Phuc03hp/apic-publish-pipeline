#!/bin/bash

FILE_NAME="apic_platform_publish_to_catalog.sh"
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

update_apic_publish_audit() {
    local product_name="$1"
    local result="$2"
    local audit_file="${WORKING_DIR_BASIC}/${AUDIT_FILENAME}"
    if [ ! -f "$audit_file" ]; then
        echo '{}' > "$audit_file"
    fi
    local current_json
    current_json=$(cat "$audit_file")
    updated_json=$(echo "$current_json" | jq --arg key "$product_name" --arg val "$result" '.Products[$key].Publish = $val')
    echo "$updated_json" > "$audit_file"
}

main() {
    local config_file="${CONFIG_FILES_DIR}/config.json"
    local toolkit_file="${CONFIG_FILES_DIR}/toolkit-creds.json"
    if [ ! -f "$config_file" ] || [ ! -f "$toolkit_file" ]; then
        echo "$INFO config.json or toolkit-creds.json not found!"
        update_stage_res "Products_API_publish" "FAILED"
        exit 1
    fi
    local APIC_PLATFORM_API_URL=$(jq -r '.APIC_PLATFORM_API_URL' "$config_file")
    local APIC_GATEWAY_URL=$(jq -r '.APIC_GATEWAY_URL' "$config_file")
    local CLIENT_ID=$(jq -r '.toolkit.client_id' "$toolkit_file")
    local CLIENT_SECRET=$(jq -r '.toolkit.client_secret' "$toolkit_file")
    local BEARER_TOKEN=$(curl -sk -X POST -H 'Content-Type: application/json' -H 'Accept: application/json' \
        -d '{"username": "'${PROV_ORG_OWNER_USERNAME}'", "password": "'${PROV_ORG_OWNER_PASSWORD}'", "realm": "'${PROV_ORG_REALM}'", "client_id": "'${CLIENT_ID}'", "client_secret": "'${CLIENT_SECRET}'", "grant_type": "password"}' \
        "${APIC_PLATFORM_API_URL}/api/token" | jq -r '.access_token')
    if [ -z "$BEARER_TOKEN" ] || [ "$BEARER_TOKEN" == "null" ]; then
        echo "$INFO Failed to get bearer token"
        update_stage_res "Products_API_publish" "FAILED"
        exit 1
    fi
    # Xóa toàn bộ products cũ
    local ORG_NAME=$(echo "$PROV_ORG_TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g')
    local DELETE_URL="${APIC_PLATFORM_API_URL}/api/catalogs/${ORG_NAME}/${PROV_ORG_CATALOG_NAME}/products?confirm=${PROV_ORG_CATALOG_NAME}"
    curl -sk -X DELETE -H "Accept: application/json" -H "Authorization: Bearer $BEARER_TOKEN" "$DELETE_URL"
    # Publish từng product
    local isSuccess=1
    for product_file in ${WORKING_DIR_BASIC}/*.yaml; do
        [ -e "$product_file" ] || continue
        # Lấy danh sách API liên quan
        local apis=( $(yq e '.apis[].name' "$product_file" 2>/dev/null | sed 's/:/_/g') )
        local files_args=(-F "product=@$product_file;type=application/json")
        for api in "${apis[@]}"; do
            [ -e "${WORKING_DIR_BASIC}/$api.yaml" ] && files_args+=( -F "openapi=@${WORKING_DIR_BASIC}/$api.yaml;type=application/json" )
        done
        local PUBLISH_URL="${APIC_PLATFORM_API_URL}/api/catalogs/${ORG_NAME}/${PROV_ORG_CATALOG_NAME}/publish?migrate_subscriptions=true"
        local resp=$(curl -sk -w '%{http_code}' -o /tmp/publish_resp.json -H "Accept: application/json" -H "Authorization: Bearer $BEARER_TOKEN" \
            -X POST "${files_args[@]}" "$PUBLISH_URL")
        local http_code=$(tail -n1 <<< "$resp")
        if [ "$http_code" == "200" ] || [ "$http_code" == "201" ]; then
            update_apic_publish_audit "$(basename $product_file .yaml)" "SUCCESS"
        else
            update_apic_publish_audit "$(basename $product_file .yaml)" "FAILED"
            isSuccess=0
        fi
    done
    if [ $isSuccess -eq 1 ]; then
        update_stage_res "Products_API_publish" "SUCCESS"
        echo "$INFO Products_API_publish SUCCESS"
    else
        update_stage_res "Products_API_publish" "FAILED"
        echo "$INFO Products_API_publish FAILED"
        exit 1
    fi
}

main 