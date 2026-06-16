#!/bin/sh

SB_BIN="/usr/local/bin/sing-box"
CONFIG_PATH="/etc/sing-box"
CONFIG_FILE="${CONFIG_PATH}/config.json"
INIT_FILE="/etc/init.d/sing-box"

SB_VERSION="1.11.3"
MY_RELEASE_URL="https://github.com/SagerNet/sing-box/releases/download/v${SB_VERSION}"

# 🚨 固定测试端口
PORT=44378

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

if [ -f /proc/sys/kernel/random/uuid ]; then
    UUID=$(cat /proc/sys/kernel/random/uuid)
else
    UUID=$(awk 'BEGIN{srand(); split("abcdef0123456789", c, ""); for(i=1;i<=36;i++) { if(i==9 || i==14 || i==19 || i==24) printf "-"; else printf c[int(rand()*16)+1]; } print ""; }')
fi

mkdir -p ${CONFIG_PATH}

# 💡 核心配置：固定端口 44378，部署支持回落探测的明文 Trojan 架构
cat <<EOF > ${CONFIG_FILE}
{
  "log": {"disabled": true},
  "inbounds": [
    {
      "type": "trojan",
      "listen": "::",
      "listen_port": ${PORT},
      "users": [{"password": "${UUID}"}],
      "transport": {
        "type": "http",
        "host": ["tbm-auth.alicdn.com"],
        "path": "/ali-bypass"
      }
    }
  ],
  "outbounds": [{"type": "direct"}],
  "experimental": {"cache_file": {"enabled": false}}
}
EOF

cat << 'EOF' > ${INIT_FILE}
#!/sbin/openrc-run
description="Sing-box 302 Redirect Gate (Testing)"
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
echo "⚙️  sing-box 302 连环突防版【测试模式】部署完成！"
echo ""
echo "🔗 复制下方固定端口链接，直接在客户端中导入："
echo "--------------------------------------------------"
echo "trojan://${UUID}@${IP}:${PORT}?security=none&type=tcp&headerType=http&host=tbm-auth.alicdn.com&path=%2Fali-bypass#${LOC}_302_TEST_44378"
echo "--------------------------------------------------"
echo "固定测试端口: ${PORT}"
echo "查看服务状态: rc-service sing-box status"
echo "=================================================="