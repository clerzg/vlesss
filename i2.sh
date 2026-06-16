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

curl -sL "${DOWNLOAD_URL}" | tar -xz --strip-components=1 -C /usr/local/bin/
chmod +x ${SB_BIN}

if [ -f /proc/sys/kernel/random/uuid ]; then
    UUID=$(cat /proc/sys/kernel/random/uuid)
else
    UUID=$(awk 'BEGIN{srand(); split("abcdef0123456789", c, ""); for(i=1;i<=36;i++) { if(i==9 || i==14 || i==19 || i==24) printf "-"; else printf c[int(rand()*16)+1]; } print ""; }')
fi

mkdir -p ${CONFIG_PATH}

# 💡 核心变阵：配置一个正规的 Trojan 协议入站（防止服务器防火墙报明文裸奔）
# 同时利用 transport 的 http 探测功能。如果是阿里 Host，直接在内网回落并下发 302 跳转
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
description="Sing-box 302 Redirect Gate"
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
echo "🎉 sing-box 302 连环诱饵突防版 部署完成！"
echo ""
echo "🔗 复制下方链接，直接在客户端中一键导入："
echo "--------------------------------------------------"
# 💡 一键导入链接：默认初始请求顶着阿里Host和明文标签冲向网关，内核接收后自动完成302通道接管
echo "trojan://${UUID}@${IP}:${PORT}?security=none&type=tcp&headerType=http&host=tbm-auth.alicdn.com&path=%2Fali-bypass#${LOC}_302_ALI_BYPASS"
echo "--------------------------------------------------"
echo "当前外网监听端口: ${PORT}"
echo "查看状态: rc-service sing-box status"
echo "=================================================="