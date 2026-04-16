# dnsmods
Xray DNS 分流自动配置工具 (DNSMods)

这是一个专为 Xray-core 设计的自动化脚本，旨在通过人机交互的方式，快速实现流媒体（YouTube/Netflix）的精准 DNS 分流解锁，同时确保非流媒体流量遵循 VPS 本地的原生 DNS 设置，兼顾解锁与访问速度。
🚀 核心功能

    智能探测：自动识别 config.json 路径，适配多种安装脚本。

    出站匹配：动态扫描 outbounds，自动锁定 freedom 协议标签，防止由于 Tag 错误导致的网络中断。

    精准分流：

        流媒体：通过用户指定的 DNS（如解锁用 DNS）解析。

        常规流量：通过系统本地 DNS 解析，避免 CDN 绕路，降低延迟。

    安全机制：自动备份原配置，执行 xray -test 语法检查，若配置有误则自动回退，确保服务高可用。

    幂等操作：使用 jq 进行 JSON 修改，多次运行不会导致配置堆叠。

📦 快速使用

在你的 VPS 终端直接执行以下一键命令：
```bash
wget -O dns_mod.sh https://raw.githubusercontent.com/pansir0290/dnsmods/main/dns_mod.sh && bash dns_mod.sh

```


🛠️ 实现原理

该脚本通过修改 Xray 的 routing 与 dns 模块，将 domainStrategy 设置为 IPOnDemand。当访问流媒体域名时，Xray 会拦截解析请求并定向发送至用户指定的解锁 DNS，从而获取特定区域的 IP 地址。
📋 依赖要求

系统：Debian / Ubuntu / CentOS

内核：Xray-core (已安装并正常运行)

工具：脚本会自动检查并安装 jq

📄 配置文件参考

运行脚本后，你的 config.json 将会自动增加如下逻辑：
JSON

"dns": {
  "servers": [
    {
      "address": "你的解锁DNS",
      "port": 53,
      "domains": ["domain:youtube.com", "domain:netflix.com", "..."]
    },
    "localhost"
  ]
}

⚠️ 注意事项

Tag 检查：请确保你的 Xray 配置中至少有一个 protocol 为 freedom 的出站规则。

客户端配置：建议在客户端（如 v2rayN/Clash）开启“嗅探 (Sniffing)”，以确保域名能正确传达至服务端触发分流逻辑。

🤝 贡献与反馈

如果你在使用过程中发现特定的流媒体域名需要补充，欢迎提交 Pull Request 或 Issue。
提示

你可以直接把这段内容复制到你 GitHub 仓库的 README.md 文件里。这样不仅看起来很专业，下次你在新服务器上部署时，直接打开仓库页面就能看到那行一键执行的命令了。
