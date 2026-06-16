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

# 🔑 让 sing-box 生成标准的 REALITY 密钥对
KEY_JSON=$(${SB_BIN} generate reality-keypair)
PRIV_KEY=$(echo "${KEY_JSON}" | awk -F'"' '/private_key/ {print $4}')
PUB_KEY=$(echo "${KEY_JSON}" | awk -F'"' '/public_key/ {print $4}')
SHORT_ID=$(head -c 8 /dev/urandom | hexdump -v -e '/1 "%02x"')

mkdir -p ${CONFIG_PATH}

# 💡 终极变阵：回归纯正 VLESS + REALITY，直接借用真白名单 HTTPS 域名进行无缝前置和回落
cat <<EOF > ${CONFIG_FILE}
{
  "log": {"disabled": true},
  "inbounds": [
    {
      "type": "vless",
      "listen": "::",
      "listen_port": ${PORT},
      "users": [
        {
          "uuid": "${UUID}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "tbm-auth.alicdn.com",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "tbm-auth.alicdn.com",
            "server_port": 443
          },
          "private_key": "${PRIV_KEY}",
          "short_id": [
            "${SHORT_ID}"
          ]
        }
      }
    }
  ],
  "outbounds": [{"type": "direct"}],
  "experimental": {"cache_file": {"enabled": false}}
}
EOF

cat << 'EOF' > ${INIT_FILE}
#!/sbin/openrc-run
description="Sing-box VLESS Reality Service"
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
echo "🎉 sing-box 纯正 VLESS+REALITY 极速版部署完成！"
echo ""
echo "🔗 复制下方链接，直接在客户端中一键导入："
echo "--------------------------------------------------"
# 💡 生成标准的、100% 走纯真阿里 TLS SNI 的直连分享链接
echo "vless://${UUID}@${IP}:${PORT}?security=reality&sni=tbm-auth.alicdn.com&pbk=${PUB_KEY}&sid=${SHORT_ID}&flow=xtls-rprx-vision&type=tcp#${LOC}_REALITY_DIRECT"
echo "--------------------------------------------------"
echo "固定测试端口: ${PORT}"
echo "查看运行状态: rc-service sing-box status"
echo "=================================================="