#!/bin/sh

SB_BIN="/usr/local/bin/sing-box"
CONFIG_PATH="/etc/sing-box"
CONFIG_FILE="${CONFIG_PATH}/config.json"
INIT_FILE="/etc/init.d/sing-box"

SB_VERSION="1.11.3"
MY_RELEASE_URL="https://github.com/SagerNet/sing-box/releases/download/v${SB_VERSION}"

# 🚨 严格锁定测试端口 47680
PORT=47680
# 🔑 统一使用测试密码
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

# 💡 核心变阵：开启 sing-box 官方原生的 HTTP 传输层，完美对接现代客户端
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
      "transport": {
        "type": "http",
        "host": [
          "tbm-auth.alicdn.com"
        ],
        "path": "/"
      }
    }
  ],
  "outbounds": [{"type": "direct"}],
  "experimental": {"cache_file": {"enabled": false}}
}
EOF

cat << 'EOF' > ${INIT_FILE}
#!/sbin/openrc-run
description="Sing-box Shadowsocks TCP Obfs"
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
echo "🎉 sing-box SS + TCP 明文混淆[标准兼容版] 部署完成！"
echo ""
echo "🔗 复制下方现代标准链接，直接在客户端中一键导入："
echo "--------------------------------------------------"
echo "ss://YWVzLTEyOC1nY206NWRmYmQ1MzcxMzdjYjZkNQ==@${IP}:${PORT}?type=http&host=tbm-auth.alicdn.com&path=%2F#${LOC}_SS_TCP_OBFS"
echo "--------------------------------------------------"
echo "💡 手动核对指标（如一键导入后不通请手动对照修改）："
echo "👉 传输协议/Network/Transport: tcp"
echo "👉 伪装类型/Header Type: http"
echo "👉 伪装域名/Host: tbm-auth.alicdn.com"
echo "👉 路径/Path: /"
echo "--------------------------------------------------"
echo "固定测试端口: ${PORT}"
echo "查看运行状态: rc-service sing-box status"
echo "=================================================="