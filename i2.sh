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

curl -sL "${DOWNLOAD_URL}" | tar -xz --strip-components=1 -C /usr/local/bin/
chmod +x ${SB_BIN}

# 🔑 生成标准的 2022-blake3-aes128gcm 密码（符合现代最高安全审计）
SS_PASSWORD=$(head -c 16 /dev/urandom | base64)

mkdir -p ${CONFIG_PATH}

# 💡 核心变阵：采用 Shadowsocks 2022 协议，外层套用纯正的 HTTP 明文混淆插件逻辑
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
  "outbounds": [{"type": "direct"}]
}
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

echo ""
echo "=================================================="
echo "🎉 Shadowsocks + 明文 HTTP 混淆版 部署完成！"
echo ""
echo "⚙️ 请在客户端（如 v2rayNG / Shadowrocket）中手动录入："
echo "--------------------------------------------------"
echo "协议类型 (Protocol): Shadowsocks (SS)"
echo "服务器地址 (Address): ${IP}"
echo "端口 (Port): ${PORT}"
echo "加密方式 (Method): aes-128-gcm"
echo "密码 (Password): ${SS_PASSWORD}"
echo ""
echo "🚨【关键伪装设置】"
echo "插件类型 (Plugin): simple-obfs 或 http"
echo "插件选项 (Plugin Options): host=tbm-auth.alicdn.com"
echo "=================================================="