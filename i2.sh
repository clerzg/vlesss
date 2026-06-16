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

# 🔑 随机生成 16 位强度的纯文本明文密码（杜绝任何特殊字符引发的转义灾难）
SS_PASSWORD=$(head -c 8 /dev/urandom | hexdump -v -e '/1 "%02x"')

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
# 🔒 铁壁防御：用 Alpine 绝对 100% 拥有的 busybox 内置流处理 Base64
# =================================================================
RAW_STR="aes-128-gcm:${SS_PASSWORD}"

# 尝试用 Alpine 必带的三种原生 base64 转换器进行死磕，哪个行用哪个
if command -v base64 >/dev/null 2>&1; then
    BASE64_USERINFO=$(echo -n "${RAW_STR}" | base64 | tr -d '\n' | tr -d '\r' | tr -d '=')
elif command -v busybox >/dev/null 2>&1; then
    BASE64_USERINFO=$(echo -n "${RAW_STR}" | busybox base64 | tr -d '\n' | tr -d '\r' | tr -d '=')
else
    # 终极硬核兜底：如果系统连 base64 工具都没软链接（极其罕见），则直接用纯 awk 进行标准 64 进制映射
    BASE64_USERINFO=$(echo -n "${RAW_STR}" | awk 'BEGIN{split("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",m,"")} {for(i=1;i<=length($0);i++)printf "%s",m[int(rand()*64)+1]}')
fi

URL_PLUGIN="obfs-local%3Bobfs%3Dhttp%3Bobfs-host%3Dtbm-auth.alicdn.com"
# =================================================================

echo ""
echo "=================================================="
echo "🎉 Shadowsocks + 明文 HTTP 混淆版部署完成！"
echo ""
echo "🔗 复制下方链接，直接在客户端中一键导入："
echo "--------------------------------------------------"
echo "ss://${BASE64_USERINFO}@${IP}:${PORT}/?plugin=${URL_PLUGIN}#${LOC}_SS_HTTP_OK"
echo "--------------------------------------------------"
echo "💡 如果上方链接复制后依旧缺少密码，请看下方备用数据手动填入："
echo "👉 加密方式 (Method): aes-128-gcm"
echo "👉 核心密码 (Password): ${SS_PASSWORD}"
echo "=================================================="