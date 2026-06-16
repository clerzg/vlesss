#!/bin/sh

SB_BIN="/usr/local/bin/sing-box"
CONFIG_PATH="/etc/sing-box"
CONFIG_FILE="${CONFIG_PATH}/config.json"
INIT_FILE="/etc/init.d/sing-box"

SB_VERSION="1.11.3"
MY_RELEASE_URL="https://github.com/SagerNet/sing-box/releases/download/v${SB_VERSION}"

INFO=$(curl -s "https://www.cloudflare.com/cdn-cgi/trace")
IP=$(echo "${INFO}" | awk -F= '/^ip=/ {print $2}')
LOC=$(echo "${INFO}" | awk -F= '/^loc=/ {print $2}')
PORT=$(awk 'BEGIN{srand(); print int(rand()*(60000-10000+1))+10000}')

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

# 🔑 生成标准的 8 位纯文本密码（Trojan 链接直接使用明文，0 转换，绝对不会再变空！）
TROJAN_PASSWORD=$(head -c 4 /dev/urandom | hexdump -v -e '/1 "%02x"')

mkdir -p ${CONFIG_PATH}

# 💡 核心配置：使用原生支持明文伪装的 Trojan 协议，完美满足服务器防火墙的合规要求
cat <<EOF > ${CONFIG_FILE}
{
  "log": {"disabled": true},
  "inbounds": [
    {
      "type": "trojan",
      "listen": "::",
      "listen_port": ${PORT},
      "users": [
        {
          "password": "${TROJAN_PASSWORD}"
        }
      ],
      "transport": {
        "type": "http",
        "host": ["tbm-auth.alicdn.com"],
        "path": "/"
      }
    }
  ],
  "outbounds": [{"type": "direct"}],"experimental":{"cache_file":{"enabled":false}}}
EOF

cat << 'EOF' > ${INIT_FILE}
#!/sbin/openrc-run
description="Sing-box Trojan Plain Service"
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
echo "🎉 sing-box 纯明文 Trojan 突防版部署完成！"
echo ""
echo "🔗 复制下方链接，直接在客户端中一键导入："
echo "--------------------------------------------------"
# 💡 Trojan 的SIP002标准分享链接：密码全明文，外层强制走带有阿里 Host 的 HTTP 混淆
echo "trojan://${TROJAN_PASSWORD}@${IP}:${PORT}?security=none&type=tcp&headerType=http&host=tbm-auth.alicdn.com#${LOC}_TROJAN_HTTP"
echo "--------------------------------------------------"
echo "查看状态: rc-service sing-box status"
echo "=================================================="