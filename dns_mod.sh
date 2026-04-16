#!/bin/bash

# ====================================================
# Project: Xray 流媒体 & AI 平台 DNS 全能分流工具
# Author: pansir0290
# ====================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}开始执行 Xray 全平台 (流媒体 + AI) DNS 分流配置...${NC}"

# 1. 查找配置文件
CONFIG_PATH="/usr/local/etc/xray/config.json"
[ ! -f "$CONFIG_PATH" ] && CONFIG_PATH="/etc/xray/config.json"

if [ ! -f "$CONFIG_PATH" ]; then
    echo -e "${RED}未找到 config.json，请确认 Xray 已安装。${NC}"
    exit 1
fi

# 2. 交互式获取 DNS IP
echo -e "${GREEN}请输入各平台对应的解锁 DNS (直接回车表示跳过):${NC}"
echo -e "${YELLOW}--- 视频流媒体 ---${NC}"
read -p "1. YouTube DNS: " YT_DNS
read -p "2. Netflix DNS: " NF_DNS
read -p "3. DisneyPlus DNS: " DS_DNS
read -p "4. HBO Max/Discovery+ DNS: " HBO_DNS
read -p "5. Amazon Prime Video DNS: " AMZ_DNS

echo -e "${YELLOW}--- 国际主流 AI 平台 ---${NC}"
read -p "6. OpenAI (ChatGPT) DNS: " OAI_DNS
read -p "7. Anthropic (Claude) DNS: " CLD_DNS
read -p "8. Google Gemini (Bard) DNS: " GMN_DNS
read -p "9. Microsoft Copilot (Bing AI) DNS: " CPL_DNS

# 3. 准备备份
cp "$CONFIG_PATH" "${CONFIG_PATH}.bak"

# 4. 自动识别出站 Tag
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

# 6. 分配域名簇
# 视频类
add_rule "$YT_DNS" '["domain:youtube.com","domain:googlevideo.com","domain:youtu.be","domain:ytimg.com"]'
add_rule "$NF_DNS" '["domain:netflix.com","domain:netflix.net","domain:nflxvideo.net","domain:nflxso.net"]'
add_rule "$DS_DNS" '["domain:disneyplus.com","domain:disney.com","domain:dssott.com"]'
add_rule "$HBO_DNS" '["domain:hbomax.com","domain:hbo.com","domain:max.com"]'
add_rule "$AMZ_DNS" '["domain:primevideo.com","domain:amazonvideo.com"]'

# AI 类 (重点域名补充)
add_rule "$OAI_DNS" '["domain:openai.com","domain:chatgpt.com","domain:oaistatic.com","domain:oaiusercontent.com"]'
add_rule "$CLD_DNS" '["domain:anthropic.com","domain:claude.ai"]'
add_rule "$GMN_DNS" '["domain:gemini.google.com","domain:bard.google.com","domain:proactive.google.com"]'
add_rule "$CPL_DNS" '["domain:bing.com","domain:edgeservices.bing.com","domain:copilot.microsoft.com"]'

# 7. 合并 JSON 并清理冗余规则
jq --argjson dns_svrs "$NEW_DNS_SERVERS" --argjson rt_rules "$NEW_ROUTING_RULES" '
.dns.servers = ($dns_svrs + ["localhost"]) |
.routing.domainStrategy = "IPOnDemand" |
.routing.rules = ($rt_rules + [.routing.rules[] | select(.domain == null or (
    (. | contains(["youtube","netflix","disney","hbomax","openai","chatgpt","anthropic","claude","gemini","bing"])) | not
))])
' "$CONFIG_PATH" > "${CONFIG_PATH}.tmp" && mv "${CONFIG_PATH}.tmp" "$CONFIG_PATH"

# 8. 检查与重启
/usr/local/bin/xray -test -config "$CONFIG_PATH"
if [ $? -eq 0 ]; then
    systemctl restart xray
    echo -e "${GREEN}流媒体与 AI 平台分流配置成功！${NC}"
else
    mv "${CONFIG_PATH}.bak" "$CONFIG_PATH"
    echo -e "${RED}配置错误，已回滚。${NC}"
fi
