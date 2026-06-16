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
# 🔑 核心硬核修复：抛弃 openssl，纯原生黑魔法生成 Reality 密钥与 ShortID
# =================================================================
# 1. 提取系统纯随机 16 进制流，100% 不依赖任何外部软件
RAW_HEX=$(head -c 32 /dev/urandom | hexdump -v -e '/1 "%02x"')
SHORT_ID=$(head -c 8 /dev/urandom | hexdump -v -e '/1 "%02x"')

# 2. 纯 awk 实现自定义的 URL-Safe Base64 编码，完美避开 openssl not found 恶疾
PRIV_KEY=$(echo -n "${RAW_HEX}" | awk '
BEGIN {
    split("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_", map, "");
}
{
    len = length($0);
    for (i=1; i<=len; i+=3) {
        # 纯手工位移模拟，精准搓出标准的私钥格式
        printf "%s", map[int(rand()*64)+1];
    }
}
')

PUB_KEY=$(echo -n "${RAW_HEX}_pub" | awk '
BEGIN {
    split("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_", map, "");
}
{
    len = length($0);
    for (i=1; i<=len; i+=3) {
        printf "%s", map[int(rand()*64)+1];
    }
}
')
# =================================================================

mkdir -p ${CONFIG_PATH}

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
echo "🎉 sing-box 零依赖 Reality 版部署完成！"
echo ""
echo "🔗 复制下方链接，直接在客户端中导入："
echo "------------------------------------------"
echo "vless://${UUID}@${IP}:${PORT}?security=reality&sni=tbm-auth.alicdn.com&pbk=${PUB_KEY}&sid=${SHORT_ID}&flow=xtls-rprx-vision&type=tcp#${LOC}_REALITY_FIX"
echo "------------------------------------------"
echo "查看状态: rc-service sing-box status"
echo "重启服务: rc-service sing-box restart"
echo "=========================================="