cat << 'EOF' > install_mtg.sh
#!/bin/sh
set -e

# 确保以 root 权限运行
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ 请使用 root 用户或 sudo 运行此脚本！"
    exit 1
fi

echo "=================================================="
echo "      Alpine Linux MTProxy (mtg) 一键安装脚本"
echo "=================================================="

# 1. 安装基础依赖
echo "📦 正在安装依赖 (curl, tar)..."
apk update && apk add --no-cache curl tar

# 2. 获取并下载最新的 mtg 版本
echo "🔍 正在获取 mtg 最新版本号..."
LATEST_VER=$(curl -s https://api.github.com/repos/9seconds/mtg/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
if [ -z "$LATEST_VER" ]; then
    LATEST_VER="v2.1.7" # 备用版本号
fi
echo "📥 正在下载 mtg ${LATEST_VER}..."

# 确定系统架构 (目前主流为 amd64/x86_64)
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    MTG_ARCH="linux-amd64"
elif [ "$ARCH" = "aarch64" ]; then
    MTG_ARCH="linux-arm64"
else
    echo "❌ 暂不支持的系统架构: $ARCH"
    exit 1
fi

# 下载并解压
cd /tmp
curl -L -O "https://github.com/9seconds/mtg/releases/download/${LATEST_VER}/mtg-${LATEST_VER#v}-${MTG_ARCH}.tar.gz"
tar -xzf "mtg-${LATEST_VER#v}-${MTG_ARCH}.tar.gz"
mv "mtg-${LATEST_VER#v}-${MTG_ARCH}/mtg" /usr/local/bin/mtg
chmod +x /usr/local/bin/mtg
rm -rf "mtg-${LATEST_VER#v}-${MTG_ARCH}"*

# 3. 配置运行参数
echo "--------------------------------------------------"
read -p "请输入 MTProxy 监听端口 (默认: 443): " PORT
PORT=${PORT:-443}

read -p "请输入要伪装的域名 (默认: cloudflare.com): " DOMAIN
DOMAIN=${DOMAIN:-cloudflare.com}

# 生成 Fake-TLS 密钥
echo "🔑 正在生成 Fake-TLS 密钥..."
SECRET=$(/usr/local/bin/mtg generate-secret "$DOMAIN")

echo "--------------------------------------------------"
echo "端口: $PORT"
echo "域名: $DOMAIN"
echo "密钥: $SECRET"
echo "--------------------------------------------------"

# 4. 写入 OpenRC 服务配置
echo "⚙️ 正在配置 OpenRC 系统服务..."
cat << SERVICE_EOF > /etc/init.d/mtg
#!/sbin/openrc-run

name="mtg-proxy"
description="MTProxy Go implementation"
command="/usr/local/bin/mtg"
command_args="run 0.0.0.0:${PORT} ${SECRET}"
command_background="yes"
pidfile="/run/\${RC_SVCNAME}.pid"

depend() {
    need net
}
SERVICE_EOF

chmod +x /etc/init.d/mtg

# 5. 启动服务并设置开机自启
echo "🚀 正在启动服务..."
rc-service mtg restart
rc-update add mtg default

# 获取公网 IP (兼容 IPv4)
IP=$(curl -s4 ip.sb || curl -s4 ifconfig.me || echo "你的服务器IP")

echo "=================================================="
echo "🎉 MTProxy 安装成功！"
echo "=================================================="
echo "代理连接地址 (点击或复制进 Telegram 即可使用):"
echo "tg://proxy?server=${IP}&port=${PORT}&secret=${SECRET}"
echo "=================================================="
EOF
chmod +x install_mtg.sh
./install_mtg.sh
