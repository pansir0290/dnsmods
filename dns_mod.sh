#!/bin/bash

# ====================================================
# Project: Xray DNS 终极自动化版 (环境自愈 + 11项全量分流)
# Author: pansir0290
# ====================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- 1. 强制补齐环境与目录自愈 ---
echo -e "${YELLOW}正在检查运行环境...${NC}"

# 确保目录存在
[ ! -d "/usr/local/bin" ] && mkdir -p /usr/local/bin
[ ! -d "/usr/local/etc/xray" ] && mkdir -p /usr/local/etc/xray

# 暴力补齐 geosite.dat (解决报错根源)
if [ ! -f "/usr/local/bin/geosite.dat" ]; then
    echo -e "${YELLOW}缺少 geosite.dat，正在强制下载...${NC}"
    wget -O /usr/local/bin/geosite.dat https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat
fi

if [ ! -f "/usr/local/bin/geoip.dat" ]; then
    echo -e "${YELLOW}缺少 geoip.dat，正在强制下载...${NC}"
    wget -O /usr/local/bin/geoip.dat https://github.com/v2fly/geoip/releases/latest/download/geoip.dat
fi

# --- 2. 交互式获取 DNS IP ---
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

# --- 3. 配置备份与出站识别 ---
CONFIG_PATH="/usr/local/etc/xray/config.json"
[ ! -f "$CONFIG_PATH" ] && CONFIG_PATH="/etc/xray/config.json"

TIMESTAMP=$(date +%s)
BACKUP_FILE="${CONFIG_PATH}.bak_${TIMESTAMP}"
cp "$CONFIG_PATH" "$BACKUP_FILE"

# 自动识别出站 Tag (direct 或 freedom)
OUTBOUND_TAG=$(jq -r '.outbounds[] | select(.protocol=="freedom") | .tag' "$CONFIG_PATH" | head -n 1)
[ -z "$OUTBOUND_TAG" ] && OUTBOUND_TAG="direct"

# --- 4. 核心逻辑函数 ---
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

# --- 5. 分配域名簇 (全量补全) ---
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

# --- 6. 注入配置并强制清理旧冲突 ---
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

# --- 7. 校验、重启与自我清理 ---
/usr/local/bin/xray -test -config "$CONFIG_PATH"
if [ $? -eq 0 ]; then
    systemctl restart xray
    echo -e "${GREEN}✅ 终极版部署成功！${NC}"
    # 自我清理旧脚本
    rm -f $0
else
    mv "$BACKUP_FILE" "$CONFIG_PATH"
    echo -e "${RED}❌ 配置失败，已恢复原始备份：$BACKUP_FILE${NC}"
fi
