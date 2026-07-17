# 江湖大侠 iOS WebView 壳子游戏项目 (kx-game-tool)

这是一个基于苹果原生 `WKWebView` (WebKit) 封装的《江湖大侠》iOS 套壳 App 项目。本项目主要解决网页端游戏在移动设备上挂机发热高、后台易断网、缓存易丢失的问题。

## 🌟 核心特性
*   **屏幕常亮 (No-Sleep)**：内置挂机常亮逻辑，防止设备闲置时进入锁屏锁死游戏。
*   **内嵌网页播放 (Inline Playback)**：完美兼容音效及视频播放，不触发全屏播放弹窗。
*   **沙盒独立缓存 (Isolated Sandbox Cache)**：独立的网络缓存空间，加速游戏静态资源载入速度，减少手机流量消耗与 CPU 解码开销。
*   **刘海屏全屏优化**：隐藏系统手势主条 (PrefersHomeIndicatorAutoHidden)，实现真正的沉浸式全屏挂机体验。
*   **防阻拦 HTTP (ATS Bypass)**：集成 `NSAppTransportSecurity` 规则，完美兼容官方的 HTTP 数据请求。

---

## 🛠️ Xcode 编译与配置指南

### 1. 本地导入
1. 克隆或下载本仓库代码到你的 Mac 电脑中。
2. 双击打开 `kx-name-ios/kx-game-ios.xcodeproj` 启动 Xcode。

### 2. 配置个人签名
1. 选择左侧 `kx-game-ios` 项目根目录，进入 **Signing & Capabilities** 标签页。
2. 勾选 **Automatically manage signing**。
3. 在 **Team** 下拉列表中选择你自己的 Apple ID 账号（免费个人证书即可）。

### 3. 连接手机运行
1. 用数据线将 iPhone 连接至电脑，在 Xcode 顶端设备栏选中你的真机设备。
2. 点击左上角 **Run（运行）** 或按快捷键 `Cmd + R` 进行部署。
3. 首次安装需在 iPhone 的 **“设置 -> 通用 -> VPN 与设备管理”** 中信任你的开发者账号。

---

## 📦 如何放置和分发 `.ipa` 安装包？

如果你想把编译好的 `.ipa` 安装包分享给你的朋友，推荐以下两种放置和使用方式：

### 方案 A：发布在 GitHub Releases（最推荐，安全、方便 🌟）
这是最标准的开源/私有仓分发形式：
1. 用之前提到的 **Payload 压缩法** 在本地打好 `江湖大侠.ipa` 安装包。
2. 在你的 GitHub 仓库主页右侧找到 **Releases**，点击 **Create a new release**（创建新发布）。
3. 填写一个版本号（如 `v1.0.0`），然后在下方上传区域直接把你的 `江湖大侠.ipa` 文件拖拽上传作为 Release 附件发布。
4. **如何下载使用**：你的朋友访问你的 GitHub Release 页面，直接下载 `.ipa` 附件，在手机上用 **TrollStore（巨魔）**、**Sideloadly** 或 **AltStore** 打开导入安装即可。

### 方案 B：使用第三方免费分发服务（免数据线扫码安装 📱）
如果你希望别人连电脑下载都省了，直接拿手机扫码就能装：
1. 将 `.ipa` 包上传到国内的免费内测分发平台，如：
   *   **蒲公英 (Pgyer)**：[https://www.pgyer.com/](https://www.pgyer.com/)
   *   **Diawi**：[https://www.diawi.com/](https://www.diawi.com/)
2. 上传成功后，平台会提供一个**专属下载页面和二维码**。
3. **如何下载使用**：你的朋友用 iPhone 扫码，在 Safari 浏览器中点击“安装”，App 就会像 App Store 里的软件一样，自动在他们桌面上下载安装！
   *   *注意：此方式只支持通过 TrollStore（巨魔）免签名辅助安装，或者你的 IPA 包中已经包含了经过他们手机 UDID 授权的证书。*
