# Snug RustDesk

简体中文 · [English](README.en.md)

Snug RustDesk 是面向自建 RustDesk 的 macOS 伴侣应用。它在被控 Mac 上创建适合控制端的虚拟屏、管理窗口布局和字号。RustDesk 继续处理连接、认证和画面传输。项目当前处于开发验证阶段。

## 构建与使用

需要 macOS 14 或更新版本、Swift 6 和可用的 Xcode 命令行工具。先在被控 Mac 与控制端配置好 RustDesk。

```sh
scripts/snug check
scripts/snug app
```

打开 `build/Snug RustDesk.app`，按提示授予辅助功能权限。在设置中配置屏幕，在菜单栏选择「手动开始伴侣会话」，随后从 RustDesk 的显示器列表切入。使用完毕时选择「结束伴侣会话并还原」。手势使用 RustDesk 原生输入。截图功能由伴侣应用单独申请录屏权限。开发包默认采用 ad-hoc 签名，重新打包后可能需要重新授权。

设置和恢复数据保存在 `~/Library/Application Support/SnugRustDesk/`，日志保存在 `~/Library/Logs/SnugRustDesk.log`。分发和应用内更新默认关闭，配置项见 [.machine.env.example](.machine.env.example)。

[产品需求](docs/PRODUCT.md) · [技术设计](docs/rustdesk-technical-design.md) · [实施清单](docs/TODO-rustdesk.md)

## 来源与许可

项目衍生自 [zephyr4123/snug](https://github.com/zephyr4123/snug)，其前身为 [AoyamaShou 的 UUyc-companion](https://github.com/aoyamashou/UUyc-companion)。两位作者的版权声明与 MIT 许可全文保留在 [LICENSE](LICENSE) 中。
