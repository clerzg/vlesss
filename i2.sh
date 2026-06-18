#!/bin/sh

SB_BIN="/usr/local/bin/sing-box"
CONFIG_PATH="/etc/sing-box"
CONFIG_FILE="${CONFIG_PATH}/config.json"
INIT_FILE="/etc/init.d/sing-box"

SB_VERSION="1.11.3"
MY_RELEASE_URL="https://github.com/SagerNet/sing-box/releases/download/v${SB_VERSION}"

PORT=47680
SS_PASSWORD="5dfbd537137cb6d5"

INFO=$(curl -s "https://www.cloudflare.com/cdn-cgi/trace")
IP=$(echo "${INFO}" | awk -F= '/^ip=/ {print $2}')
LOC=$(echo "${INFO}" | awk -F= '/^loc=/ {print $2}')

echo "==== 下载官方全功能版 sing-box ===="
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64) SB_ARCH="amd64" ;;
    aarch64|arm64) SB_ARCH="arm64" ;;
    *) SB_ARCH="amd64" ;;
esac

DOWNLOAD_URL="${MY_RELEASE_URL}/sing-box-${SB_VERSION}-linux-${SB_ARCH}.tar.gz"
mkdir -p /usr/local/bin
curl -sL "${DOWNLOAD_URL}" | tar -xz --strip-components=1 -C /usr/local/bin/
chmod +x ${SB_BIN}

mkdir -p ${CONFIG_PATH}

# 服务端依然使用成熟稳定的 obfs-server 接收明文 HTTP
cat <<EOF > ${CONFIG_FILE}
{
  "log": {"disabled": true},
  "inbounds": [
    {
      "type": "shadowsocks",
      "listen": "::",
      "listen_port": ${PORT},
      "method": "aes-128-gcm",
      "password": "${SS_PASSWORD}",
      "plugin": "obfs-server",
      "plugin_options": "obfs=http"
    }
  ],
  "outbounds": [{"type": "direct"}],
  "experimental": {"cache_file": {"enabled": false}}
}
EOF

cat << 'EOF' > ${INIT_FILE}
#!/sbin/openrc-run
description="Sing-box Shadowsocks Native Obfs"
command="/usr/local/bin/sing-box"
command_args="run -c /etc/sing-box/config.json"
pidfile="/run/${RC_SVCNAME}.pid"
command_background="yes"
export GOGC=20
export GOMEMLIMIT=25MiB
respawn_delay=1
respawn_max=0
EOF

chmod +x ${INIT_FILE}
rc-update add sing-box default
rc-service sing-box restart

echo ""
echo "=================================================="
echo "🎉 服务端配置成功！下面为您提供客户端直连 URL 链接："
echo "=================================================="
echo "👉 复制下方链接在 sing-box 客户端中添加 Profile，"
echo "👉 并在 Type（类型）中直接选择 URL（远程导入）："
echo "--------------------------------------------------"
echo "ss://YWVzLTEyOC1nY206NWRmYmQ1MzcxMzdjYjZkNQ==@${IP}:${PORT}?plugin=simple-obfs%3Bobfs%3Dhttp%3Bobfs-host%3Dtbm-auth.alicdn.com#${LOC}_SS_OBFS"
echo "=================================================="