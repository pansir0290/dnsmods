#!/bin/bash

# ====================================================
# Project: Xray 流媒体 DNS 精准分流配置工具
# Author: pansir0290 (Modified for IT Pro)
# ====================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}开始执行 Xray DNS 分流自动配置...${NC}"

# 1. 查找 Xray 配置文件位置
CONFIG_PATH=""
SEARCH_PATHS=(
    "/usr/local/etc/xray/config.json"
    "/etc/xray/config.json"
    "/usr/local/bin/config.json"
)

for path in "${SEARCH_PATHS[@]}"; do
    if [ -f "$path" ]; then
        CONFIG_PATH=$path
        break
    fi
done

if [ -z "$CONFIG_PATH" ]; then
    echo -e "${RED}错误：未找到 Xray 配置文件，请手动指定路径。${NC}"
    read -p "请输入 config.json 的完整路径: " CONFIG_PATH
fi

if [ ! -f "$CONFIG_PATH" ]; then
    echo -e "${RED}路径无效，退出。${NC}"
    exit 1
fi

echo -e "${GREEN}检测到配置文件: $CONFIG_PATH${NC}"

# 2. 检查并安装 jq
if ! command -v jq &> /dev/null; then
    echo "正在安装必要的 JSON 处理工具 jq..."
    apt-get update && apt-get install -y jq
fi

# 3. 人机交互获取 DNS IP
read -p "请输入用于流媒体解锁的 DNS IP (例如 5.102.125.55): " MEDIA_DNS

# 校验 IP 格式
if [[ ! $MEDIA_DNS =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo -e "${RED}无效的 IP 格式，退出。${NC}"
    exit 1
fi

# 4. 自动识别 Outbound Tag
# 寻找 protocol 为 freedom 的 tag，如果找不到则默认用 direct
OUTBOUND_TAG=$(jq -r '.outbounds[] | select(.protocol=="freedom") | .tag' "$CONFIG_PATH" | head -n 1)
if [ -z "$OUTBOUND_TAG" ] || [ "$OUTBOUND_TAG" == "null" ]; then
    OUTBOUND_TAG="direct"
fi

echo -e "识别到出站标签为: ${YELLOW}$OUTBOUND_TAG${NC}"

# 5. 备份原配置
cp "$CONFIG_PATH" "${CONFIG_PATH}.bak"

# 6. 使用 jq 修改配置
# 注入 DNS 规则和路由规则
jq --arg mdns "$MEDIA_DNS" --arg tag "$OUTBOUND_TAG" '
.dns = {
  "servers": [
    {
      "address": $mdns,
      "port": 53,
      "domains": [
        "domain:youtube.com",
        "domain:googlevideo.com",
        "domain:youtu.be",
        "domain:ytimg.com",
        "domain:ggpht.com",
        "domain:netflix.com",
        "domain:netflix.net",
        "domain:nflxvideo.net",
        "domain:nflxext.com",
        "domain:nflxso.net"
      ]
    },
    "localhost"
  ]
} |
.routing.domainStrategy = "IPOnDemand" |
.routing.rules = [
  {
    "type": "field",
    "outboundTag": $tag,
    "domain": [
      "domain:youtube.com",
      "domain:googlevideo.com",
      "domain:youtu.be",
      "domain:ytimg.com",
      "domain:ggpht.com",
      "domain:netflix.com",
      "domain:netflix.net",
      "domain:nflxvideo.net",
      "domain:nflxext.com",
      "domain:nflxso.net"
    ]
  }
] + [.routing.rules[] | select(.domain | index("youtube.com") | not)]
' "$CONFIG_PATH" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_PATH"

# 7. 语法检查与重启
xray -test -config "$CONFIG_PATH"
if [ $? -eq 0 ]; then
    systemctl restart xray
    echo -e "${GREEN}配置成功并已重启 Xray！${NC}"
    echo -e "流媒体正在通过 ${YELLOW}$MEDIA_DNS${NC} 进行解锁。"
else
    mv "${CONFIG_PATH}.bak" "$CONFIG_PATH"
    echo -e "${RED}配置语法错误，已自动回滚备份。请检查 config.json 结构。${NC}"
fi
