#!/bin/sh

# 1. 彻底杀掉所有可能占内存的旧服务
rc-service sing-box stop 2>/dev/null
rc-service xray stop 2>/dev/null
killall -9 sing-box xray 2>/dev/null

X_BIN="/usr/local/bin/xray"
CONFIG_PATH="/etc/xray"
CONFIG_FILE="${CONFIG_PATH}/config.json"
INIT_FILE="/etc/init.d/xray"

echo "==== 正在通过 tar.gz 流式解压安装轻量版 Xray ===="
mkdir -p /usr/local/bin ${CONFIG_PATH}

# 💡 核心变阵：直接通过管道流式解压，0 磁盘缓存，极低内存占用
curl -sL "https://github.com/clerzg/light-vless/releases/download/v26.3.27/xray-linux-64.tar.gz" | tar -xz -C /usr/local/bin/

# 确保赋予执行权限
chmod +x ${X_BIN}

echo "==== 正在写入经典 SS + HTTP 混淆配置 ===="
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

# 3. 写入极限内存锁死守护脚本
cat << 'EOF' > ${INIT_FILE}
#!/sbin/openrc-run
description="Xray Shadowsocks HTTP Obfs"
command="/usr/local/bin/xray"
command_args="run -c /etc/xray/config.json"
pidfile="/run/${RC_SVCNAME}.pid"
command_background="yes"
export GOGC=10
export GOMEMLIMIT=20MiB
EOF

chmod +x ${INIT_FILE}
rc-update add xray default
rc-service xray restart

echo ""
echo "=================================================="
echo "🎉 Xray-core 经典混淆引擎已通过 tar.gz 安全部署完毕！"
echo "=================================================="
echo "固定测试端口: 47680"
echo "查看运行状态: rc-service xray status"
echo "=================================================="