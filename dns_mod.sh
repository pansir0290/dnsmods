#!/bin/bash

# ====================================================
# Project: Xray DNS 分流全能修复版 (解决 Fast.com 测速问题)
# Author: pansir0290
# ====================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. 查找配置文件
CONFIG_PATH="/usr/local/etc/xray/config.json"
[ ! -f "$CONFIG_PATH" ] && CONFIG_PATH="/etc/xray/config.json"

if [ ! -f "$CONFIG_PATH" ]; then
    echo -e "${RED}未找到 config.json${NC}"
    exit 1
fi

# 2. 交互式获取 DNS IP
echo -e "${GREEN}请输入各平台对应的解锁 DNS (直接回车表示跳过):${NC}"
read -p "1. YouTube DNS (如 5.102.125.55): " YT_DNS
read -p "2. Netflix/Fast.com DNS (如 22.22.22.22): " NF_DNS
read -p "3. OpenAI/ChatGPT DNS: " OAI_DNS
read -p "4. Google Gemini DNS: " GMN_DNS

# 3. 准备备份
cp "$CONFIG_PATH" "${CONFIG_PATH}.bak"

# 4. 识别出站 Tag
OUTBOUND_TAG=$(jq -r '.outbounds[] | select(.protocol=="freedom") | .tag' "$CONFIG_PATH" | head -n 1)
[ -z "$OUTBOUND_TAG" ] && OUTBOUND_TAG="direct"

# 5. 定义处理函数
NEW_DNS_SERVERS="[]"
NEW_ROUTING_RULES="[]"

add_rule() {
    local dns_ip=$1
    local domains=$2
    if [ -n "$dns_ip" ]; then
        NEW_DNS_SERVERS=$(echo $NEW_DNS_SERVERS | jq --arg ip "$dns_ip" --argjson doms "$domains" '. += [{"address": $ip, "port": 53, "domains": $doms}]')
        NEW_ROUTING_RULES=$(echo $NEW_ROUTING_RULES | jq --arg tag "$OUTBOUND_TAG" --argjson doms "$domains" '. += [{"type": "field", "outboundTag": $tag, "domain": $doms}]')
    fi
}

# 6. 分配域名簇 (重点补全了 Netflix 测速域名)
add_rule "$YT_DNS" '["domain:youtube.com","domain:googlevideo.com","domain:youtu.be","domain:ytimg.com"]'
add_rule "$NF_DNS" '["domain:netflix.com","domain:fast.com","domain:netflix.net","domain:nflxvideo.net","domain:nflxext.com","domain:nflxso.net"]'
add_rule "$OAI_DNS" '["domain:openai.com","domain:chatgpt.com","domain:oaistatic.com","domain:oaiusercontent.com"]'
add_rule "$GMN_DNS" '["domain:gemini.google.com","domain:bard.google.com"]'

# 7. 合并 JSON (核心修复逻辑：清空旧规则，置顶新规则)
# 使用 select 过滤掉包含关键词的旧规则，避免配置无限堆叠
jq --argjson dns_svrs "$NEW_DNS_SERVERS" --argjson rt_rules "$NEW_ROUTING_RULES" '
.dns.servers = ($dns_svrs + ["localhost"]) |
.routing.domainStrategy = "IPOnDemand" |
.routing.rules = ($rt_rules + [.routing.rules[] | select(.domain == null or (
    (. | contains(["youtube","netflix","fast.com","nflx","openai","chatgpt","gemini"])) | not
))])
' "$CONFIG_PATH" > "${CONFIG_PATH}.tmp" && mv "${CONFIG_PATH}.tmp" "$CONFIG_PATH"

# 8. 检查与重启
/usr/local/bin/xray -test -config "$CONFIG_PATH"
if [ $? -eq 0 ]; then
    systemctl restart xray
    echo -e "${GREEN}全能版配置成功！已包含 Fast.com 测速分流。${NC}"
else
    mv "${CONFIG_PATH}.bak" "$CONFIG_PATH"
    echo -e "${RED}配置错误，已自动回滚。请检查 jq 是否安装。${NC}"
fi
