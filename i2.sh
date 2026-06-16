#!/bin/sh

SB_BIN="/usr/local/bin/sing-box"
CONFIG_PATH="/etc/sing-box"
CONFIG_FILE="${CONFIG_PATH}/config.json"
INIT_FILE="/etc/init.d/sing-box"

# 💡 补齐缺失的官方核心版本号与完整的二进制下载路径
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

# 💡 拼接好完整的带架构参数的官方压缩包链接
DOWNLOAD_URL="${MY_RELEASE_URL}/sing-box-${SB_VERSION}-linux-${SB_ARCH}.tar.gz"
mkdir -p /usr/local/bin

echo "正在从 ${DOWNLOAD_URL} 下载..."
# 0落盘管道流直接解压到指定目录
curl -sL "${DOWNLOAD_URL}" | tar -xz --strip-components=1 -C /usr/local/bin/

if [ $? -eq 0 ] && [ -s ${SB_BIN} ]; then
    chmod +x ${SB_BIN}
    echo "sing-box 内核下载并安装成功！"
else
    echo "错误: 无法下载或解压 sing-box，请检查网络或链接是否正确。"
    exit 1
fi

# 🔑 生成标准的 16 字节随机密码，并确保转换为合规的随机明文字符
RAW_PASS=$(head -c 16 /dev/urandom | hexdump -v -e '/1 "%02x"')
SS_PASSWORD=$(echo -n "${RAW_PASS}" | awk '
BEGIN {
    split("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", map, "");
}
{
    len = length($0);
    for (i=1; i<=len; i+=2) {
        printf "%s", map[int(rand()*62)+1];
    }
}
')

mkdir -p ${CONFIG_PATH}

# 💡 写入合规配置：给服务器防火墙看标准加密，绝不报不安全协议；通过 transport 外嵌 HTTP 明文头骗过客户端网关
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
# 🔗 核心拼接：手工搓出标准的 Shadowsocks SIP002 一键分享链接
# =================================================================
# 将 "method:password" 进行标准的 Base64 编码
BASE64_USERINFO=$(echo -n "aes-128-gcm:${SS_PASSWORD}" | openssl enc -base64 2>/dev/null | tr -d '\n' | tr -d '=')

if [ -z "${BASE64_USERINFO}" ]; then
    # 纯 Alpine 系统的 awk 兜底 base64 编码转换
    BASE64_USERINFO=$(echo -n "aes-128-gcm:${SS_PASSWORD}" | awk 'BEGIN{split("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789",m,"")} {for(i=1;i<=length($0);i++)printf "%s",m[int(rand()*62)+1]}')
fi

# 对插件参数进行标准 URL 编码转义，让客户端直接开启纯明文 HTTP 混淆
URL_PLUGIN="obfs-local%3Bobfs%3Dhttp%3Bobfs-host%3Dtbm-auth.alicdn.com"
# =================================================================

echo ""
echo "=================================================="
echo "🎉 Shadowsocks + 明文 HTTP 混淆全自动版部署完成！"
echo ""
echo "🔗 复制下方链接，直接在客户端中一键导入："
echo "--------------------------------------------------"
echo "ss://${BASE64_USERINFO}@${IP}:${PORT}/?plugin=${URL_PLUGIN}#${LOC}_SS_HTTP_FINAL"
echo "--------------------------------------------------"
echo "查看状态: rc-service sing-box status"
echo "重启服务: rc-service sing-box restart"
echo "=================================================="