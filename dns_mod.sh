#!/bin/bash

# ====================================================
# Project: Xray DNS 终极全能全量版 (V6 - 11项交互)
# Author: pansir0290
# ====================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

CONFIG_PATH="/usr/local/etc/xray/config.json"
[ ! -f "$CONFIG_PATH" ] && CONFIG_PATH="/etc/xray/config.json"

# 1. 欢迎信息与交互
echo -e "${YELLOW}开始执行 Xray 全平台 DNS 分流配置 (V6 全量版)...${NC}"
echo -e "${GREEN}请输入各平台对应的解锁 DNS (示例 8.8.8.8，回车跳过):${NC}"

echo -e "${YELLOW}--- 视频流媒体 ---${NC}"
read -p "1. YouTube DNS: " YT_DNS
read -p "2. Netflix/Fast.com DNS: " NF_DNS
read -p "3. DisneyPlus DNS: " DS_DNS
read -p "4. HBO/Max/Discovery+ DNS: " HBO_DNS
read -p "5. Amazon Prime Video DNS: " AMZ_DNS
read -p "6. Hulu DNS: " HULU_DNS
read -p "7. TVB/Viu/BiliBili(港澳台) DNS: " SEA_DNS

echo -e "${YELLOW}--- 国际主流 AI 平台 ---${NC}"
read -p "8. OpenAI (ChatGPT) DNS: " OAI_DNS
read -p "9. Anthropic (Claude) DNS: " CLD_DNS
read -p "10. Google Gemini DNS: " GMN_DNS
read -p "11. Microsoft Copilot DNS: " CPL_DNS

# 2. 备份
cp "$CONFIG_PATH" "${CONFIG_PATH}.bak_$(date +%s)"

# 3. 识别出站 Tag
OUTBOUND_TAG=$(jq -r '.outbounds[] | select(.protocol=="freedom") | .tag' "$CONFIG_PATH" | head -n 1)
[ -z "$OUTBOUND_TAG" ] && OUTBOUND_TAG="direct"

# 4. 构建函数
NEW_DNS_SERVERS="[]"
NEW_ROUTING_RULES="[]"

add_rule() {
    local dns_ip=$1
    local domains=$2
    if [ -n "$dns_ip" ]; then
        NEW_DNS_SERVERS=$(echo $NEW_DNS_SERVERS | jq --arg ip "$dns_ip" --argjson doms "$domains" '. += [{"address": $ip, "port": 53, "domains": $doms, "skipFallback": true}]')
        NEW_ROUTING_RULES=$(echo $NEW_ROUTING_RULES | jq --arg tag "$OUTBOUND_TAG" --argjson doms "$domains" '. += [{"type": "field", "outboundTag": $tag, "domain": $doms}]')
    fi
}

# 5. 分配域名簇 (全量补全)
add_rule "$YT_DNS" '["domain:youtube.com","domain:googlevideo.com","domain:youtu.be","domain:ytimg.com","domain:ggpht.com"]'
add_rule "$NF_DNS" '["domain:netflix.com","domain:fast.com","domain:netflix.net","domain:nflxvideo.net","domain:nflxext.com","domain:nflxso.net","domain:nflximg.net","geosite:netflix"]'
add_rule "$DS_DNS" '["domain:disneyplus.com","domain:disney.com","domain:dssott.com","domain:disneylatino.com"]'
add_rule "$HBO_DNS" '["domain:hbomax.com","domain:hbo.com","domain:discovery.com","domain:max.com"]'
add_rule "$AMZ_DNS" '["domain:primevideo.com","domain:amazonvideo.com","domain:pv-cdn.net"]'
add_rule "$HULU_DNS" '["domain:hulu.com","domain:huluim.com","domain:hulustream.com"]'
add_rule "$SEA_DNS" '["domain:tvb.com","domain:viu.com","domain:bilibili.com"]'
add_rule "$OAI_DNS" '["domain:openai.com","domain:chatgpt.com","domain:oaistatic.com","domain:oaiusercontent.com"]'
add_rule "$CLD_DNS" '["domain:anthropic.com","domain:claude.ai"]'
add_rule "$GMN_DNS" '["domain:gemini.google.com","domain:bard.google.com","domain:proactive.google.com"]'
add_rule "$CPL_DNS" '["domain:bing.com","domain:edgeservices.bing.com","domain:copilot.microsoft.com"]'

# 6. 合并 JSON 并解决回环与测速定位
# 加入 UseIPv4 策略，防止 IPv6 绕过分流导致定位失败
jq --argjson dns_svrs "$NEW_DNS_SERVERS" --argjson rt_rules "$NEW_ROUTING_RULES" '
.dns.servers = ($dns_svrs + ["localhost"]) |
.dns.queryStrategy = "UseIPv4" |
.routing.domainStrategy = "IPOnDemand" |
.routing.rules = ($rt_rules + [.routing.rules[] | select(
    (.domain | tostring | (
        contains("youtube") or contains("netflix") or contains("fast.com") or 
        contains("disney") or contains("hbomax") or contains("primevideo") or 
        contains("hulu") or contains("tvb") or contains("viu") or 
        contains("openai") or contains("chatgpt") or contains("anthropic") or 
        contains("claude") or contains("gemini") or contains("bing") or contains("nflx")
    )) | not
)])
' "$CONFIG_PATH" > "${CONFIG_PATH}.tmp" && mv "${CONFIG_PATH}.tmp" "$CONFIG_PATH"

# 7. 检查与重启
/usr/local/bin/xray -test -config "$CONFIG_PATH"
if [ $? -eq 0 ]; then
    systemctl restart xray
    echo -e "${GREEN}✅ 终极全量版配置成功！共处理 11 项分流规则。${NC}"
else
    mv "${CONFIG_PATH}.bak_*" "$CONFIG_PATH"
    echo -e "${RED}❌ 配置错误，已自动回滚。${NC}"
fi
