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

echo "==== 正在检测系统架构并准备下载官方全功能版 sing-box ===="
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64) SB_ARCH="amd64" ;;
    aarch64|arm64) SB_ARCH="arm64" ;;
    *) SB_ARCH="amd64" ;;
esac

DOWNLOAD_URL="${MY_RELEASE_URL}/sing-box-${SB_VERSION}-linux-${SB_ARCH}.tar.gz"
mkdir -p /usr/local/bin

echo "正在从 ${DOWNLOAD_URL} 下载..."
curl -sL "${DOWNLOAD_URL}" | tar -xz --strip-components=1 -C /usr/local/bin/

if [ $? -eq 0 ] && [ -s ${SB_BIN} ]; then
    chmod +x ${SB_BIN}
    echo "sing-box 内核下载并安装成功！"
else
    echo "错误: 无法下载或解压 sing-box"
    exit 1
fi

# 🔑 随机生成符合 aes-128-gcm 的 16 位规范密码
SS_PASSWORD=$(head -c 16 /dev/urandom | hexdump -v -e '/1 "%02x"' | head -c 16)

mkdir -p ${CONFIG_PATH}

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
        "host": ["tbm-auth.alicdn.com"],
        "path": "/"
      }
    }
  ],
  "outbounds": [{"type": "direct"}],"experimental":{"cache_file":{"enabled":false}}}
EOF

cat << 'EOF' > ${INIT_FILE}
#!/sbin/openrc-run
description="Sing-box Shadowsocks Obfs Service"
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

# =================================================================
# 🔒 核心修复：直接借用 sing-box 工具链生成完美的 Base64 编码
# =================================================================
# 用 sing-box 官方内置命令把 "aes-128-gcm:密码" 压成标准的 Base64
# 彻底断绝系统 openssl/awk 抽风导致返回空密码的可能
RAW_STR="aes-128-gcm:${SS_PASSWORD}"
BASE64_USERINFO=$(${SB_BIN} tool base64 encode "${RAW_STR}" 2>/dev/null | tr -d '\n' | tr -d '\r' | tr -d '=')

# 拼装官方标准的混淆插件 URL 编码参数
URL_PLUGIN="obfs-local%3Bobfs%3Dhttp%3Bobfs-host%3Dtbm-auth.alicdn.com"
# =================================================================

echo ""
echo "=================================================="
echo "🎉 Shadowsocks + 明文 HTTP 混淆一键版部署完成！"
echo ""
echo "🔗 复制下方链接，直接在客户端中一键导入："
echo "--------------------------------------------------"
echo "ss://${BASE64_USERINFO}@${IP}:${PORT}/?plugin=${URL_PLUGIN}#${LOC}_SS_HTTP_OK"
echo "--------------------------------------------------"
echo "查看状态: rc-service sing-box status"
echo "重启服务: rc-service sing-box restart"
echo "=================================================="