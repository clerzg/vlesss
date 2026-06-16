#!/bin/sh

SB_BIN="/usr/local/bin/sing-box"
CONFIG_PATH="/etc/sing-box"
CONFIG_FILE="${CONFIG_PATH}/config.json"
INIT_FILE="/etc/init.d/sing-box"
MY_RELEASE_URL="https://github.com/SagerNet/sing-box/releases/download/v1.11.3"

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

# 0落盘管道流解压官方内核
curl -sL "${DOWNLOAD_URL}" | tar -xz --strip-components=1 -C /usr/local/bin/

if [ $? -eq 0 ] && [ -s ${SB_BIN} ]; then
    chmod +x ${SB_BIN}
else
    echo "错误: 无法下载或解压 sing-box"
    exit 1
fi

if [ -f /proc/sys/kernel/random/uuid ]; then
    UUID=$(cat /proc/sys/kernel/random/uuid)
else
    UUID=$(awk 'BEGIN{srand(); split("abcdef0123456789", c, ""); for(i=1;i<=36;i++) { if(i==9 || i==14 || i==19 || i==24) printf "-"; else printf c[int(rand()*16)+1]; } print ""; }')
fi

# =================================================================
# 🔑 终极完美修复：利用刚刚安装的 sing-box 官方命令原生生成合法的 Reality 密钥
# =================================================================
mkdir -p ${CONFIG_PATH}

# 让 sing-box 自己生成标准的 X25519 密钥对并用 awk 精准切割提取
KEY_JSON=$(${SB_BIN} generate reality-keypair)
PRIV_KEY=$(echo "${KEY_JSON}" | awk -F'"' '/private_key/ {print $4}')
PUB_KEY=$(echo "${KEY_JSON}" | awk -F'"' '/public_key/ {print $4}')

# 同样利用系统底层生成合法的 16 位 ShortID
SHORT_ID=$(head -c 8 /dev/urandom | hexdump -v -e '/1 "%02x"')
# =================================================================

# 写入完美的 Reality 单行一行流 JSON 配置
cat <<EOF > ${CONFIG_FILE}
{"log":{"disabled":true},"inbounds":[{"type":"vless","listen":"::","listen_port":${PORT},"users":[{"uuid":"${UUID}","flow":"xtls-rprx-vision"}],"tls":{"enabled":true,"server_name":"tbm-auth.alicdn.com","reality":{"enabled":true,"handshake":{"server":"tbm-auth.alicdn.com","server_port":443},"private_key":"${PRIV_KEY}","short_id":["${SHORT_ID}"]}}}],"outbounds":[{"type":"direct"}],"experimental":{"cache_file":{"enabled":false}}}
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
echo "🎉 sing-box 官方原生 Reality 版部署完成！"
echo ""
echo "🔗 复制下方链接，直接在客户端中导入："
echo "------------------------------------------"
echo "vless://${UUID}@${IP}:${PORT}?security=reality&sni=tbm-auth.alicdn.com&pbk=${PUB_KEY}&sid=${SHORT_ID}&flow=xtls-rprx-vision&type=tcp#${LOC}_REALITY_FINAL"
echo "------------------------------------------"
echo "查看状态: rc-service sing-box status"
echo "重启服务: rc-service sing-box restart"
echo "=========================================="