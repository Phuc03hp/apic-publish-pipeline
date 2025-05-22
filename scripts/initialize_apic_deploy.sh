#!/bin/bash

FILE_NAME="initialize_apic_deploy.sh"
INFO="[${FILE_NAME}] - "
WORKING_DIR_BASIC="../WORKSPACE"
AUDIT_FILENAME="apic-pipeline-audit.json"

# Hàm ghi trạng thái vào file audit
update_stage_res() {
    local stage_name="$1"
    local stage_res="$2"
    local audit_file="${WORKING_DIR_BASIC}/${AUDIT_FILENAME}"

    # Tạo file audit nếu chưa có
    if [ ! -f "$audit_file" ]; then
        echo '{}' > "$audit_file"
    fi

    # Đọc nội dung hiện tại
    local current_json
    current_json=$(cat "$audit_file")

    # Cập nhật trạng thái stage
    # Sử dụng jq để thao tác với JSON (cần cài jq)
    updated_json=$(echo "$current_json" | jq --arg stage "$stage_name" --arg res "$stage_res" \
        '.STAGE_SUMMARY[$stage] = {"Result": $res}')

    echo "$updated_json" > "$audit_file"
}

# Hàm tạo workspace
create_workspace_dir() {
    echo "${INFO}Current directory: $(pwd)"
    echo "${INFO}Workspace: ${WORKING_DIR_BASIC}"
    if [ ! -d "$WORKING_DIR_BASIC" ]; then
        mkdir -p "$WORKING_DIR_BASIC"
    fi
}

# Main
main() {
    if create_workspace_dir; then
        echo "${INFO}Initialize_APIC_Deploy SUCCESS"
        update_stage_res "Initialize_APIC_Deploy" "SUCCESS"
    else
        echo "[ERROR] - Exception in ${FILE_NAME}"
        update_stage_res "Initialize_APIC_Deploy" "FAILED"
        exit 1
    fi
}

main 