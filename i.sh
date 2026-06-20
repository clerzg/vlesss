#!/bin/sh

SB_BIN="/usr/local/bin/sing-box"
CONFIG_PATH="/etc/sing-box"
CONFIG_FILE="${CONFIG_PATH}/config.json"
INIT_FILE="/etc/init.d/sing-box"
MY_RELEASE_URL="https://github.com/clerzg/vlesss/releases/latest/download"

INFO=$(curl -s "https://www.cloudflare.com/cdn-cgi/trace")
IP=$(echo "${INFO}" | awk -F= '/^ip=/ {print $2}')
LOC=$(echo "${INFO}" | awk -F= '/^loc=/ {print $2}')
PORT=$(awk 'BEGIN{srand(); print int(rand()*50000)+10000}')

echo "下载 sing-box"
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64) SB_ARCH="amd64" ;;
    aarch64|arm64) SB_ARCH="arm64" ;;
    *) SB_ARCH="amd64" ;;
esac

DOWNLOAD_URL="${MY_RELEASE_URL}/sing-box-linux-${SB_ARCH}.tar.xz"
mkdir -p /usr/local/bin

curl -sL -# "${DOWNLOAD_URL}" | tar -xf -C /usr/local/bin/

if [ $? -eq 0 ] && [ -s ${SB_BIN} ]; then
    chmod +x ${SB_BIN}
else
    echo "错误: 无法下载sing-box"
    exit 1
fi

if [ -f /proc/sys/kernel/random/uuid ]; then
    UUID=$(cat /proc/sys/kernel/random/uuid)
else
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

cat <<EOF > ${CONFIG_FILE}
{"log":{"disabled":true},"inbounds":[{"type":"vless","listen":"::","listen_port":${PORT},"users":[{"uuid":"${UUID}"}],"transport":{"type":"http","host":[]}}],"outbounds":[{"type":"direct"}]}
EOF

cat << 'EOF' > ${INIT_FILE}
#!/sbin/openrc-run
description="Sing-box Minimal Service"
command="/usr/local/bin/sing-box"
command_args="run -c /etc/sing-box/config.json"
pidfile="/run/${RC_SVCNAME}.pid"
command_background="yes"

export GOGC=10
export GOMEMLIMIT=20MiB

respawn_delay=1
respawn_max=0
EOF

chmod +x ${INIT_FILE}
rc-update add sing-box default
rc-service sing-box start

echo ""
echo "🎉 sing-box 部署完成！"
echo ""
echo "🚀节点链接："
echo "vless://${UUID}@${IP}:${PORT}?headerType=http&host=tbm-auth.alicdn.com#${LOC}"

echo ""
echo ""
echo "查看状态: rc-service sing-box status"
echo ""