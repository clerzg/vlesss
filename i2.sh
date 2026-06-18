#!/bin/sh

X_BIN="/usr/local/bin/xray"
CONFIG_PATH="/etc/ray"
CONFIG_FILE="${CONFIG_PATH}/config.json"
INIT_FILE="/etc/init.d/xray"
# 💡 完美对接你提供的极轻量流式解压直链
DOWNLOAD_URL="https://github.com/clerzg/light-vless/releases/download/v26.3.27/xray-linux-64.tar.gz"

INFO=$(curl -s "https://www.cloudflare.com/cdn-cgi/trace")
IP=$(echo "${INFO}" | awk -F= '/^ip=/ {print $2}')
LOC=$(echo "${INFO}" | awk -F= '/^loc=/ {print $2}')

# 🛠️ 修复核心：用 printf 彻底剥离 awk 生成随机端口时自带的换行符
RAW_PORT=$(awk 'BEGIN{srand(); print int(rand()*(60000-10000+1))+10000}')
PORT=$(printf "%s" "$RAW_PORT" | tr -d '\n' | tr -d '\r')

echo "==== 下载 xray ===="
mkdir -p /usr/local/bin

# 💡 完美沿用你的流式管道下载解压逻辑（绝不 OOM）
curl -sL -# "${DOWNLOAD_URL}" | tar -xz -C /usr/local/bin/

if [ $? -eq 0 ] && [ -s ${X_BIN} ]; then
    chmod +x ${X_BIN}
else
    echo "错误: 无法下载xray"
    exit 1
fi

# 🔑 密码生成：用时间戳 md5 截取 16 位绝对纯净的复制粘贴字符串，100% 不破坏 JSON 结构
SS_PASSWORD=$(date +%s%N | md5sum | head -c 16)

mkdir -p ${CONFIG_PATH}

# 💡 完美对齐 v2rayNG 内核自适应的 Shadowsocks + HTTP 混淆原生配置
cat <<EOF > ${CONFIG_FILE}
{"log":{"loglevel":"none"},"inbounds":[{"port":${PORT},"protocol":"shadowsocks","settings":{"method":"aes-128-gcm","password":"${SS_PASSWORD}","network":"tcp"},"streamSettings":{"network":"tcp","tcpSettings":{"header":{"type":"http","request":{"version":"1.1","method":"GET","path":["/"],"headers":{"Host":["tbm-auth.alicdn.com"]}}}}}}],"outbounds":[{"protocol":"freedom"}]}
EOF

# 💡 完美沿用你习惯的 OpenRC 守护配置
cat << 'EOF' > ${INIT_FILE}
#!/sbin/openrc-run
description="Xray Shadowsocks HTTP Obfs"
command="/usr/local/bin/xray"
command_args="run -c /etc/ray/config.json"
pidfile="/run/${RC_SVCNAME}.pid"
command_background="yes"

export GOGC=10
export GOMEMLIMIT=20MiB
EOF

chmod +x ${INIT_FILE}
rc-update add xray default
rc-service xray start

# 3. 全自动生成标准且无换行污染的 v2rayNG 专属安全导入链接
CIPHER_B64=$(echo -n "aes-128-gcm:${SS_PASSWORD}" | base64 | tr -d '\n' | tr -d '\r')

echo ""
echo "=========================================="
echo "🎉 xray 部署完成！"
echo ""
echo "节点链接 (Shadowsocks + HTTP-Obfs 格式)："
echo "ss://${CIPHER_B64}@${IP}:${PORT}/?plugin=obfs-local%3Bobfs%3Dhttp%3Bobfs-host%3Dtbm-auth.alicdn.com#${LOC}_XRAY_RAND"

echo ""
echo "=========================================="
echo "查看状态: rc-service xray status"
echo "重启服务: rc-service xray restart"
echo "停止服务: rc-service xray stop"
echo "=========================================="