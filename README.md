# 🚀 Xray DNS 流媒体 & AI 全量分流工具 (dnsmods)

这是一个专为 Xray/V2Ray 用户设计的交互式 DNS 分流配置脚本。通过简单的交互，即可实现 YouTube、Netflix (含 Fast.com 测速)、Disney+ 及主流 AI 平台（ChatGPT/Claude/Gemini）的精准分流解锁。

## 🌟 核心功能

- **全平台支持**：内置 7 大视频流媒体 + 4 大主流 AI 平台域名簇。
- **自动修复 Fast.com**：补全 `nflxvideo` 等测速域名，解决测速定位不准或转圈问题。
- **防回环逻辑**：引入 `skipFallback` 和 `UseIPv4` 策略，防止 DNS 解析死循环。
- **智能识别**：自动识别系统出站标签（如 `direct` 或 `freedom`），无需手动修改。
- **安全备份**：每次运行都会自动备份原 `config.json`，支持错误自动回滚。

---

## 🛠️ 快速使用

在你的 VPS 终端直接执行以下一键命令：

```bash
wget -O dns_mod.sh [https://raw.githubusercontent.com/pansir0290/dnsmods/main/dns_mod.sh](https://raw.githubusercontent.com/pansir0290/dnsmods/main/dns_mod.sh) && bash dns_mod.sh
