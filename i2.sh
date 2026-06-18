#!/bin/sh

# 停止旧的 sing-box 腾出端口
rc-service sing-box stop 2>/dev/null

X_BIN="/usr/local/bin/xray"
CONFIG_PATH="/etc/xray"
CONFIG_FILE="${CONFIG_PATH}/config.json"
INIT_FILE="/etc/init.d/xray"

# 下载官方经典全功能 Xray 内核
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64) X_ARCH="64" ;;
    aarch64|arm64) X_ARCH="arm64-v8a" ;;
    *) X_ARCH="64" ;;
esac

echo "==== 正在安装 Xray-core (${X_ARCH}) ===="
mkdir -p /usr/local/bin ${CONFIG_PATH}
curl -sL "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-${X_ARCH}.zip" -o /tmp/xray.zip
unzip -o /tmp/xray.zip -d /tmp/xray_tmp
mv /tmp/xray_tmp/xray /usr/local/bin/xray
chmod +x ${X_BIN}
rm -rf /tmp/xray.zip /tmp/xray_tmp

# 写入 Xray 标杆级的 Shadowsocks + HTTP 混淆配置
cat <<EOF > ${CONFIG_FILE}
{
  "log": {"loglevel": "none"},
  "inbounds": [
    {
      "port": 47680,
      "protocol": "shadowsocks",
      "settings": {
        "method": "aes-128-gcm",
        "password": "5dfbd537137cb6d5",
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

# 配置 OpenRC 守护
cat << 'EOF' > ${INIT_FILE}
#!/sbin/openrc-run
description="Xray Shadowsocks HTTP Obfs"
command="/usr/local/bin/xray"
command_args="run -c /etc/xray/config.json"
pidfile="/run/${RC_SVCNAME}.pid"
command_background="yes"
EOF

chmod +x ${INIT_FILE}
rc-update add xray default
rc-service xray restart

echo "=================================================="
echo "🎉 服务端已无缝切换至 Xray-core 经典混淆引擎！"
echo "=================================================="