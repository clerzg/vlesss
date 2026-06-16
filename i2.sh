#!/bin/sh

SB_BIN="/usr/local/bin/sing-box"
CONFIG_PATH="/etc/sing-box"
CONFIG_FILE="${CONFIG_PATH}/config.json"
INIT_FILE="/etc/init.d/sing-box"
# 💡 官方全功能 Release 下载源
MY_RELEASE_URL="https://github.com/SagerNet/sing-box/releases/download/v1.11.3"

# 💡 确保本地有 openssl 工具来生成证书
if ! command -v openssl >/dev/null 2>&1; then
    apk update && apk add --no-cache openssl >/dev/null 2>&1
fi

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

DOWNLOAD_URL="${MY_RELEASE_URL}/sing-box-1.11.3-linux-${SB_ARCH}.tar.gz"
mkdir -p /usr/local/bin

# 💡 纯原生解压流：用 curl -sL 静音下载，直接用 tar -xv 并在解压时只抓取 sing-box 二进制
# 这样既做到了 0 磁盘占用，又利用 tar 原生内核管道，绝不损坏数据
curl -sL "${DOWNLOAD_URL}" | tar -xz --strip-components=1 -C /usr/local/bin/ "*/sing-box"

if [ $? -eq 0 ] && [ -s ${SB_BIN} ]; then
    chmod +x ${SB_BIN}
    echo "解压成功！"
else
    echo "错误: 无法下载或解压 sing-box"
    exit 1
fi

if [ -f /proc/sys/kernel/random/uuid ]; then
    UUID=$(cat /proc/sys/kernel/random/uuid)
else
    UUID=$(awk 'BEGIN{
        srand();
        split("abcdef0123456789", c, "");
        for(i=1;i<=36;i++) {
            if(i==9 || i==14 || i==19 || i==24) printf "-";
            else printf c[int(rand()*16)+1];
        }
        print "";
    }')
fi

mkdir -p ${CONFIG_PATH}

# 本地离线为白名单域名搓出一套 TLS 证书
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout ${CONFIG_PATH}/server.key \
  -out ${CONFIG_PATH}/server.crt \
  -subj "/CN=tbm-auth.alicdn.com" >/dev/null 2>&1

# 严格遵循单行一行流 JSON 格式，升级为 WebSocket + TLS
cat <<EOF > ${CONFIG_FILE}
{"log":{"disabled":true},"inbounds":[{"type":"vless","listen":"::","listen_port":${PORT},"users":[{"uuid":"${UUID}"}],"tls":{"enabled":true,"server_name":"tbm-auth.alicdn.com","certificate_path":"${CONFIG_PATH}/server.crt","key_path":"${CONFIG_PATH}/server.key"},"transport":{"type":"ws","path":"/vless-ws","headers":{"Host":"tbm-auth.alicdn.com"}}}],"outbounds":[{"type":"direct"}],"experimental":{"cache_file":{"enabled":false}}}
EOF

cat << 'EOF' > ${INIT_FILE}
#!/sbin/openrc-run
description="Sing-box Hardcore Minimal Service"
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
echo "=========================================="
echo "🎉 sing-box 现代加密版部署完成！"
echo ""
echo "🔗 复制下方链接，直接在客户端中导入："
echo "------------------------------------------"
echo "vless://${UUID}@${IP}:${PORT}?security=tls&sni=tbm-auth.alicdn.com&allowInsecure=1&type=ws&path=%2Fvless-ws&host=tbm-auth.alicdn.com#${LOC}_WS_TLS"
echo "------------------------------------------"
echo "查看状态: rc-service sing-box status"
echo "重启服务: rc-service sing-box restart"
echo "=========================================="