#!/bin/sh

SB_BIN="/usr/local/bin/sing-box"
CONFIG_PATH="/etc/sing-box"
CONFIG_FILE="${CONFIG_PATH}/config.json"
INIT_FILE="/etc/init.d/sing-box"
# 已替换为你指定的最新发布地址
MY_RELEASE_URL="https://github.com/clerzg/vlesss/releases/latest/download"

echo "==== 1. 环境分析与数据获取 ===="
INFO=$(wget -qO- --no-cache "https://www.cloudflare.com/cdn-cgi/trace")
IP=$(echo "${INFO}" | awk -F= '/^ip=/ {print $2}')
LOC=$(echo "${INFO}" | awk -F= '/^loc=/ {print $2}')
# 随机生成 10000-60000 之间的端口
PORT=$(awk 'BEGIN{srand(); print int(rand()*(60000-10000+1))+10000}')

echo "IP: ${IP} | 区域: ${LOC} | 随机端口: ${PORT}"

echo "==== 2. 流式下载 sing-box 二进制文件 ===="
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64) SB_ARCH="amd64" ;;
    aarch64|arm64) SB_ARCH="arm64" ;;
    *) SB_ARCH="amd64" ;;
esac

DOWNLOAD_URL="${MY_RELEASE_URL}/sing-box-linux-${SB_ARCH}.tar.gz"
mkdir -p /usr/local/bin

# 流式下载并直接解压到 /usr/local/bin，不产生临时垃圾文件，极省内存
wget -O- "${DOWNLOAD_URL}" | tar -xz -C /usr/local/bin/

if [ $? -eq 0 ] && [ -s ${SB_BIN} ]; then
    chmod +x ${SB_BIN}
    echo "下载并解压成功: sing-box-linux-${SB_ARCH}"
else
    echo "错误: 无法下载或解压 sing-box 文件"
    exit 1
fi

echo "==== 3. 生成配置与 OpenRC 服务注册 ===="
if [ -f /proc/sys/kernel/random/uuid ]; then
    UUID=$(cat /proc/sys/kernel/random/uuid)
else
    # 如果系统没有 uuid 模块，使用标准 sh 随机生成一个伪 UUID
    UUID=$(awk 'BEGIN{
        srand();
        split("abcdef0123456789", c, "");
        for(i=1;i<=36;i++) {
            if(i==9 || i==14 || i==19 || i==24) printf "-";
            else printf c[int(rand()*16)+1];
        }
        print "";
    }')
fi

mkdir -p ${CONFIG_PATH}
# sing-box 紧凑版配置，动态注入端口和 UUID
cat <<EOF > ${CONFIG_FILE}
{"log":{"disabled":true},"inbounds":[{"type":"vless","listen":"0.0.0.0","listen_port":${PORT},"users":[{"uuid":"${UUID}"}],"transport":{"type":"http","host":[]}}],"outbounds":[{"type":"direct"}],"experimental":{"cache_file":{"enabled":false}}}
EOF

# 写入 OpenRC 服务脚本
cat << 'EOF' > ${INIT_FILE}
#!/sbin/openrc-run
description="Sing-box Hardcore Minimal Service"
command="/usr/local/bin/sing-box"
# sing-box 启动参数为 run -c
command_args="run -c /etc/sing-box/config.json"
pidfile="/run/${RC_SVCNAME}.pid"
command_background="yes"

# 针对 64MB 内存小鸡的 Go 运行时神级优化
#export GOGC=20
#export GOMEMLIMIT=32MiB

respawn_delay=1
respawn_max=0

depend() {
    need net
}
EOF

chmod +x ${INIT_FILE}
rc-update add sing-box default >/dev/null 2>&1
rc-service sing-box stop >/dev/null 2>&1
rc-service sing-box start

echo ""
echo "=========================================="
echo "🎉 sing-box 部署完成！"
echo ""
echo "节点链接 (VLESS + HTTP-Transport 格式)："
echo "vless://${UUID}@${IP}:${PORT}?headerType=http&host=tbm-auth.alicdn.com#${LOC}"

echo ""
echo "=========================================="
echo "💡 常用 OpenRC 指令："
echo "查看状态: rc-service sing-box status"
echo "重启服务: rc-service sing-box restart"
echo "停止服务: rc-service sing-box stop"
echo "=========================================="