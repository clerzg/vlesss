#!/bin/sh

X_BIN="/usr/local/bin/xray"
CONFIG_PATH="/etc/ray"
CONFIG_FILE="${CONFIG_PATH}/config.json"
INIT_FILE="/etc/init.d/xray"

# 1. 纯粹随机生成端口（10000-65535）与 16 位高强度密码
PORT=$(awk 'BEGIN{srand();print int(rand()*(65535-10000))+10000}')
SS_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)

# 获取服务器真实 IP 和地理位置简称
INFO=$(curl -s "https://www.cloudflare.com/cdn-cgi/trace")
IP=$(echo "${INFO}" | awk -F= '/^ip=/ {print $2}')
LOC=$(echo "${INFO}" | awk -F= '/^loc=/ {print $2}')

echo "==== 正在流式解压安装轻量版 Xray ===="
mkdir -p /usr/local/bin ${CONFIG_PATH}

# 使用极其节省内存的管道流式解压
curl -sL "https://github.com/clerzg/light-vless/releases/download/v26.3.27/xray-linux-64.tar.gz" | tar -xz -C /usr/local/bin/
chmod +x ${X_BIN}

echo "==== 正在写入 SS + HTTP 混淆配置 ===="
cat <<EOF > ${CONFIG_FILE}
{
  "log": {"loglevel": "none"},
  "inbounds": [
    {
      "port": ${PORT},
      "protocol": "shadowsocks",
      "settings": {
        "method": "aes-128-gcm",
        "password": "${SS_PASSWORD}",
        "network": "tcp"
      },
      "streamSettings": {
        "network": "tcp",
        "tcpSettings": {
          "header": {
            "type": "http",
            "request": {
              "version": "1.1",
              "method": "GET",
              "path": ["/"],
              "headers": {
                "Host": ["tbm-auth.alicdn.com"]
              }
            }
          }
        }
      }
    }
  ],
  "outbounds": [{"protocol": "freedom"}]
}
EOF

# 2. 写入极限内存锁死守护脚本（专治 64MB 小鸡）
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

echo "==== 正在启动服务并设置开机自启 ===="
rc-update add xray default
rc-service xray start

# 3. 自动拼装生成标准的 v2rayNG 导入链接
CIPHER_B64=$(echo -n "aes-128-gcm:${SS_PASSWORD}" | base64 | tr -d '\n' | tr -d '\r')

echo ""
echo "=================================================="
echo "🎉 全新纯净小鸡 Xray 混淆引擎部署完毕！"
echo "=================================================="
echo "🎯 本次随机分配端口: ${PORT}"
echo "🔑 本次随机高强密码: ${SS_PASSWORD}"
echo "--------------------------------------------------"
echo "🔗 复制下方链接，直接在 v2rayNG 中从剪贴板导入："
echo "--------------------------------------------------"
echo "ss://${CIPHER_B64}@${IP}:${PORT}/?plugin=obfs-local%3Bobfs%3Dhttp%3Bobfs-host%3Dtbm-auth.alicdn.com#${LOC}_SS_OBFS_RAND"
echo "=================================================="