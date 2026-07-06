# FRP Client

一款基于 SwiftUI 构建的 macOS 原生 FRP 客户端应用，提供图形化界面来管理和配置 [frp](https://github.com/fatedier/frp)（快速反向代理）客户端。

## 功能特性

- **服务器配置** — 图形化管理 FRP 服务器连接参数（地址、端口、认证令牌、TLS、传输协议等）
- **代理规则管理** — 支持 TCP / UDP / HTTP / HTTPS / STCP / XTCP 等多种代理类型，卡片式布局，支持内联编辑
- **流量监控** — 实时流量图表、上传/下载速率、每日流量统计、连接数监控（基于 Swift Charts）
- **运行日志** — 分类日志展示，支持日志等级筛选，可导出日志
- **一键启停** — 工具栏快速启动/停止 frpc 服务，自动检测并终止残留进程
- **开机自启** — 可选跟随系统启动自动运行 frpc 服务（基于 SMAppService）
- **双显示模式** — 支持 Dock 栏模式与菜单栏（状态栏）模式切换
- **GitHub 镜像下载** — 内置多个 GitHub 镜像代理，方便国内用户下载 frpc 二进制文件
- **TOML 配置生成** — 自动生成标准 frpc.toml 配置文件

## 系统要求

- macOS 13.0 (Ventura) 及以上版本
- Apple Silicon (arm64) 或 Intel (x86_64)

## 安装

### 方式一：直接下载（推荐）

从 [Releases](../../releases) 页面下载最新版本的 `.dmg` 文件，打开后将 `FRP Client.app` 拖入 `应用程序` 文件夹。

### 清除隔离属性

首次运行时，macOS 可能会阻止未签名的应用打开。请在终端执行以下命令清除隔离标记：

```bash
sudo xattr -r -d com.apple.quarantine /Applications/FRP\ Client.app
```

执行后双击应用即可正常启动。

### 方式二：从源码构建

```bash
git clone https://github.com/timBen9527/frp_client.git
cd frp-client/FRPClient
open FRPClient.xcodeproj
```

在 Xcode 中选择 `FRP Client` scheme，按 `Cmd + R` 构建并运行。

## 使用说明

### 基本流程

1. **配置服务器** — 在「服务器设置」中填写 FRP 服务器地址、端口和认证信息
2. **添加代理规则** — 在「代理规则」中添加需要转发的服务（如 SSH、Web 等）
3. **启动服务** — 点击右上角的「启动」按钮，frpc 将自动连接服务器
4. **查看监控** — 在「流量监控」页面查看实时带宽和流量统计

### 导航菜单

| 页面 | 说明 |
|------|------|
| 系统概览 | 运行状态总览、实时指标、配置摘要 |
| 服务器设置 | FRP 服务器连接参数配置 |
| 代理规则 | 管理转发规则（TCP/UDP/HTTP/HTTPS/STCP/XTCP） |
| 流量监控 | 实时流量图表、上传/下载速率、连接数 |
| 运行日志 | frpc 运行日志，支持等级筛选 |
| 应用设置 | 显示模式、开机自启、版本信息、数据管理 |

### 显示模式

- **Dock 栏模式** — 应用在 Dock 栏显示图标，适合频繁使用的场景
- **菜单栏模式** — 应用仅在菜单栏显示图标，不占用 Dock 空间，适合后台常驻

## 技术栈

- **语言** — Swift 5.9+
- **框架** — SwiftUI（声明式 UI）
- **架构** — MVVM（Model-View-ViewModel）
- **最低部署** — macOS 13.0
- **数据可视化** — Swift Charts
- **进程管理** — Foundation Process
- **登录项管理** — SMAppService (ServiceManagement)

## 常见问题

**Q: 应用无法打开，提示"无法验证开发者"**

在终端执行：
```bash
sudo xattr -r -d com.apple.quarantine /Applications/FRP\ Client.app
```

**Q: 启动 frpc 失败，提示端口被占用**

应用会在启动前自动检测并终止残留的 frpc 进程。如果仍有问题，请手动执行：
```bash
killall frpc
```

**Q: 流量监控页无数据**

确保 frpc 服务已成功启动（右上角显示「停止」按钮），且 Admin API 端口（默认 7400）可访问。

## 许可证

本项目基于 [Apache License 2.0](LICENSE) 开源。

FRP 项目 ([fatedier/frp](https://github.com/fatedier/frp)) 同样遵循 Apache License 2.0。
