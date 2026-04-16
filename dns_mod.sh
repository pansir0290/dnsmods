#!/bin/bash

# ====================================================
# Project: Xray DNS 终极全能版 (含资源文件自动补齐)
# Author: pansir0290
# ====================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

CONFIG_PATH="/usr/local/etc/xray/config.json"
[ ! -f "$CONFIG_PATH" ] && CONFIG_PATH="/etc/xray/config.json"

# --- 1. 自动补齐 geosite.dat 和 geoip.dat ---
check_geo_files() {
    local geo_dir="/usr/local/bin"
    # 部分安装版本可能在 /usr/local/share/xray
    [ ! -d "$geo_dir" ] && geo_dir="/usr/local/share/xray"
    
    if [ ! -f "$geo_dir/geosite.dat" ] || [ ! -f "$geo_dir/geoip.dat" ]; then
        echo -e "${YELLOW}检测到缺少资源文件，正在自动补齐到 $geo_dir...${NC}"
        wget -O "$geo_dir/geosite.dat" https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat
        wget -O "$geo_dir/geoip.dat" https://github.com/v2fly/geoip/releases/latest/download/geoip.dat
        echo -e "${GREEN}资源文件补齐完成。${NC}"
    fi
}

check_geo_files

# --- 2. 交互式获取 DNS IP ---
echo -e "${YELLOW}开始执行 Xray 全平台 DNS 分流配置 (V6.1 稳定版)...${NC}"
echo -e "${GREEN}请输入各平台对应的解锁 DNS (回车跳过):${NC}"

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

# --- 3. 备份与识别 ---
BACKUP_FILE="${CONFIG_PATH}.bak_$(date +%s)"
cp "$CONFIG_PATH" "$BACKUP_FILE"

OUTBOUND_TAG=$(jq -r '.outbounds[] | select(.protocol=="freedom") | .tag' "$CONFIG_PATH" | head -n 1)
[ -z "$OUTBOUND_TAG" ] && OUTBOUND_TAG="direct"

# --- 4. 构建函数 ---
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

# --- 5. 分配域名簇 ---
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

# --- 6. 合并 JSON ---
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

# --- 7. 检查与重启 ---
/usr/local/bin/xray -test -config "$CONFIG_PATH"
if [ $? -eq 0 ]; then
    systemctl restart xray
    echo -e "${GREEN}✅ 脚本执行成功！已自动补齐资源文件并完成分流。${NC}"
else
    mv "$BACKUP_FILE" "$CONFIG_PATH"
    echo -e "${RED}❌ 配置校验失败，已自动恢复备份。${NC}"
fi
