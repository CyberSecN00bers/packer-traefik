#!/bin/bash

# ==============================================================================
# SCRIPT QUẢN LÝ TRAEFIK DYNAMIC CONFIG
# ==============================================================================
# Usage:
#   ./manage-proxy.sh add <domain> <url> <verify_tls: true|false>
#   ./manage-proxy.sh del <domain>
#
# Example:
#   ./manage-proxy.sh add wazuh.local https://172.16.99.11:443 false
#   ./manage-proxy.sh del wazuh.local
# ==============================================================================

# Cấu hình đường dẫn tới thư mục chứa file yaml
# Nếu chạy trên máy local (trước khi build Packer):
# CONFIG_DIR="./files/dynamic_conf"

# Nếu chạy trên server thật (sau khi deploy):
CONFIG_DIR="/opt/guacamole/dynamic_conf"

mkdir -p "$CONFIG_DIR"

# Hàm hiển thị hướng dẫn sử dụng
show_help() {
    echo "Usage: $0 {add|del} [arguments]"
    echo ""
    echo "Commands:"
    echo "  add <domain> <target_url> [verify_tls]"
    echo "      domain:     Domain name (e.g., app.local)"
    echo "      target_url: Destination URL (e.g., http://10.0.0.5:8080)"
    echo "      verify_tls: (Optional) true/false. Default: true"
    echo ""
    echo "  del <domain>"
    echo "      Remove configuration for the specific domain"
    echo ""
    exit 1
}

# Hàm chuẩn hóa tên file từ domain (thay dấu . bằng _)
sanitize_filename() {
    echo "$1" | sed 's/\./_/g'
}

# ==============================================================================
# LOGIC CHÍNH
# ==============================================================================

ACTION=$1

if [ -z "$ACTION" ]; then
    show_help
fi

case "$ACTION" in
    "add")
        DOMAIN=$2
        TARGET=$3
        VERIFY_TLS=${4:-true} # Mặc định là true nếu không nhập

        if [ -z "$DOMAIN" ] || [ -z "$TARGET" ]; then
            echo "[ERROR] Missing domain or target URL."
            show_help
        fi

        FILENAME=$(sanitize_filename "$DOMAIN")
        FILEPATH="$CONFIG_DIR/${FILENAME}.yml"

        # Tách scheme (http/https) và address từ Target URL
        # Nếu user nhập 172.16.0.1:443 -> Mặc định hiểu là http nếu không có prefix
        if [[ "$TARGET" != http* ]]; then
            TARGET="http://$TARGET"
        fi

        echo "[INFO] Generating config for $DOMAIN -> $TARGET (Verify TLS: $VERIFY_TLS)..."

        # Tạo nội dung YAML
cat > "$FILEPATH" <<EOF
http:
  routers:
    router-${FILENAME}:
      rule: "Host(\`${DOMAIN}\`)"
      service: "service-${FILENAME}"
      entryPoints:
        - "web"

  services:
    service-${FILENAME}:
      loadBalancer:
        servers:
          - url: "${TARGET}"
        serversTransport: "transport-${FILENAME}"

  serversTransports:
    transport-${FILENAME}:
      insecureSkipVerify: $( [ "$VERIFY_TLS" == "false" ] && echo "true" || echo "false" )
EOF

        echo "[SUCCESS] Created config at: $FILEPATH"
        ;;

    "del")
        DOMAIN=$2
        if [ -z "$DOMAIN" ]; then
            echo "[ERROR] Missing domain to delete."
            show_help
        fi

        FILENAME=$(sanitize_filename "$DOMAIN")
        FILEPATH="$CONFIG_DIR/${FILENAME}.yml"

        if [ -f "$FILEPATH" ]; then
            rm "$FILEPATH"
            echo "[SUCCESS] Deleted config for domain: $DOMAIN"
        else
            echo "[WARNING] Config file for '$DOMAIN' not found at $FILEPATH"
        fi
        ;;

    *)
        echo "[ERROR] Unknown command: $ACTION"
        show_help
        ;;
esac
