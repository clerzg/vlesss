#!/bin/sh

SB_BIN="/usr/local/bin/sing-box"
CONFIG_PATH="/etc/sing-box"
CONFIG_FILE="${CONFIG_PATH}/config.json"
INIT_FILE="/etc/init.d/sing-box"

SB_VERSION="1.11.3"
MY_RELEASE_URL="https://github.com/SagerNet/sing-box/releases/download/v${SB_VERSION}"

# 🚨 固定测试端口（已由 44378 修改为 47680）
PORT=47680

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

# 🔑 随机生成符合 aes-128-gcm 规范的 16 位纯文本文明密码（不含特殊转义字符）
SS_PASSWORD=$(head -c 8 /dev/urandom | hexdump -v -e '/1 "%02x"')

mkdir -p ${CONFIG_PATH}

# 💡 核心变阵：部署原生支持 TCP 头部明文拼接的 Shadowsocks 架构
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
        "host": [
          "tbm-auth.alicdn.com"
        ],
        "path": "/"
      }
    }
  ],
  "outbounds": [{"type": "direct"}],
  "experimental": {"cache_file": {"enabled": false}}
}
EOF

cat << 'EOF' > ${INIT_FILE}
#!/sbin/openrc-run
description="Sing-box Shadowsocks TCP Obfs"
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

# 🔗 拼装符合 SIP002 标准的通用明文扩展参数（由客户端导入时自行在本地完成 Base64 转换）
URL_PLUGIN="obfs-local%3Bobfs%3Dhttp%3Bobfs-host%3Dtbm-auth.alicdn.com"

echo ""
echo "=================================================="
echo "🎉 sing-box 纯正 Shadowsocks + TCP 明文混淆版部署完成！"
echo ""
echo "🔗 复制下方链接，直接在客户端中一键导入："
echo "--------------------------------------------------"
echo "ss://aes-128-gcm:${SS_PASSWORD}@${IP}:${PORT}/?plugin=${URL_PLUGIN}#${LOC}_SS_TCP_HTTP"
echo "--------------------------------------------------"
echo "💡 调试备用明文数据（若一键导入不成功可手动填入）："
echo "👉 加密方式 (Method): aes-128-gcm"
echo "👉 核心密码 (Password): ${SS_PASSWORD}"
echo "👉 伪装类型/传输层 (Plugin/Header): TCP + HTTP (Host: tbm-auth.alicdn.com)"
echo "--------------------------------------------------"
echo "固定测试端口: ${PORT}"
echo "查看运行状态: rc-service sing-box status"
echo "=================================================="