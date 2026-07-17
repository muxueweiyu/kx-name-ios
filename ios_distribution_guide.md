# iOS 游戏套壳打包、TrollStore 安全分发与 TestFlight 上架指南 🚀

本指南详细记录了将 `kx.hdhive.com` H5 游戏打包为原生 iOS App，并安全清除个人签名证书进行分发的完整操作步骤。

---

## 📂 第一部分：在 Xcode 中新建并配置项目

### 1. 新建 `kx-game-ios` 工程
1.  启动 Xcode，选择 **File -> New -> Project**。
2.  选择 **iOS -> App**，点击 **Next**。
3.  填写项目配置：
    *   **Product Name**（项目名称）：输入 `kx-game-ios`
    *   **Organization Identifier**：输入 `com.weiyu`（或自定义英文标示符）
    *   **Interface**：选择 **Storyboard**（切勿选择 SwiftUI）
    *   **Language**：选择 **Swift**
4.  点击 **Next**，选择好本地存放路径，保存工程。

### 2. 替换 `ViewController.swift` 代码
双击打开 `ViewController.swift`，按 `Cmd + A` 全选清空，粘贴以下代码：

```swift
import UIKit
import WebKit

class ViewController: UIViewController, WKNavigationDelegate {

    var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 1. 强制屏幕常亮（挂机不锁屏）
        UIApplication.shared.isIdleTimerDisabled = true
        
        // 2. 初始化网页视图配置
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.allowsInlineMediaPlayback = true // 允许网页内嵌播放媒体
        
        // 3. 创建 WKWebView，并自适应屏幕尺寸
        webView = WKWebView(frame: self.view.bounds, configuration: webConfiguration)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        
        // 4. 将 WebView 添加 to 当前主视图中
        self.view.addSubview(webView)
        
        // 5. 载入游戏的官方网页地址
        if let url = URL(string: "http://kx.hdhive.com/") {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    // 6. 自动隐藏底部的横条（iPhone 底部手势栏）
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
}
```

### 3. 修改 Target 系统配置页
在 Xcode 最左侧文件树顶部点击蓝色图标 **`kx-game-ios`**，确保中间大区域选择的是 **`TARGETS -> kx-game-ios`**。

#### A. 设置最低兼容版本 (General 标签页)
*   找到 **Minimum Deployments**，将 **iOS** 下拉框设为 **`15.0`**（确保能向下兼容多款旧 iPhone 设备）。

#### B. 配置 HTTP 放行与中文显示名 (Info 标签页)
*   在 **Custom iOS Target Properties** 表格中，鼠标悬浮并点击 `+` 号：
    *   添加 **`App Transport Security Settings`**（类型为 Dictionary）。
    *   点击其左侧灰色箭头让其展开指向下方，在其子行点击 `+` 号：
        *   添加 **`Allow Arbitrary Loads`**（类型为 Boolean），并将 Value 设为 **`YES`**。
*   在表格任意空行点击 `+` 号：
    *   添加 **`Bundle Display Name`**（类型为 String），值设定为 **`江湖大侠`**。

#### C. 配置超清图标 (Assets 目录)
1.  点击左侧文件树中的 **`Assets`**（带有蓝色文件夹图标）。
2.  点击左侧列表中的 **`AppIcon`**。
3.  在 Xcode 右侧属性面板中，将 **iOS** 下拉菜单设定为 **`Single Size`**。
4.  将你的 **`app_icon.png`**（确保分辨率正好为 **`1024x1024`** 像素）拖入中间唯一的 **`1024x1024`** 大格子里。
5.  *(可选)* 点击 Assets 列表最下方 `+` 号选择 **Color Set** 并重命名为 **`AccentColor`** 消除警告。

#### D. 设置个人证书签名 (Signing & Capabilities 标签页)
1.  勾选 **`Automatically manage signing`**。
2.  在 **`Team`** 下拉菜单中，选择你的个人 Apple ID：**`Tantai Weiyu (Personal Team)`**。

---

## 📦 第二部分：打包为 TrollStore（巨魔）适用的安全 `.ipa` 裸包

巨魔商店并不需要复杂的官方付费证书，它接受任何干净的 `.ipa` 安装包。出于隐私保护和账户安全考虑，分发前必须进行**脱签（去签名）**处理。

> [!WARNING]
> ### ⚠️ 自签证书隐私风险说明
> 自签后的 `.ipa` 包内含有 `embedded.mobileprovision` 文件，此文件以明文记录了你的**真实姓名、Apple ID 邮箱和注册的手机设备号**。
> 若直接将带签名的包发给他人，会导致隐私全面泄露，且如果多人在未授权设备上强行载入该证书，可能引发苹果风控机制对你的 Apple ID 进行**永久封禁**！

### 1. 编译 App 文件
1.  在 Xcode 顶部设备栏，切换设备为 **`Any iOS Device (arm64)`**。
2.  按下快捷键 **`Cmd + B`**（编译项目）。
3.  编译成功后，点击 Xcode 顶部菜单栏的 **Product -> Show Build Folder in Finder**。
4.  在弹出的 Finder 文件夹中，进入：`Build` -> `Products` -> `Debug-iphoneos` 目录。
5.  你会看到一个带有小飞人图标的文件夹：**`kx-game-ios.app`**。

### 2. 制作 `.ipa` 包
1.  在桌面上新建一个名为 **`Payload`** 的文件夹（**注意：首字母 `P` 必须大写**）。
2.  把编译出来的 **`kx-game-ios.app`** 复制，粘贴进 **`Payload`** 文件夹中。
3.  右键点击这个 **`Payload`** 文件夹，选择 **“压缩 Payload”（Compress "Payload"）**。
4.  将生成的压缩包 **`Payload.zip`**，重命名为 **`江湖大侠.ipa`**。

### 3. 一键脱签与隐私擦除（核心步骤 🌟）
在 Mac 终端中进入生成的 `江湖大侠.ipa` 所在的文件夹，执行以下指令，从 ZIP 架构中直接强行剥离你的签名数据和个人描述文件：
```bash
zip -d 江湖大侠.ipa "Payload/*.app/embedded.mobileprovision" "Payload/*.app/_CodeSignature/*" "Payload/*.app/_CodeSignature"
```
终端会输出 `deleting: ...` 的提示。此操作完成后，该包即成为 100% 匿名、安全的**“无签裸包”**，任何人均可使用巨魔商店直接安装，且无任何隐私痕迹。

### 4. 无法安装巨魔用户的本地自签方案（爱思助手）
如果接收包的用户设备无法安装巨魔商店，请引导他们使用自己的电脑和自己的 Apple ID 账户通过**爱思助手**进行安全自签：
1.  在 Windows 电脑上打开 **爱思助手**，连接 iPhone 至电脑。
2.  点击 **`工具箱`** -> 选择 **`IPA 签名`**。
3.  导入你分享给他的无签名 `江湖大侠.ipa` 裸包。
4.  勾选 **`使用 Apple ID 签名`** -> 点击 **`添加 Apple ID`**，输入**他自己的 Apple ID 账号与密码**。
5.  选中他的账号，点击 **`开始签名`**。
6.  签名完成后，直接在列表中点击 **`安装`** 刷入手机。
7.  首次打开，需在手机的 **“设置 -> 通用 -> VPN 与设备管理”** 中信任他本人的账号。

---

## 🌐 第三部分：使用官方 TestFlight 内测分发

使用 TestFlight 可以免去收集用户手机 UDID，像正式上架一样直接通过链接分发。

> [!IMPORTANT]
> **前提条件**：你必须购买苹果官方开发者计划（**$99/年**），免费账号不支持上传至 App Store Connect。

### 1. 在苹果开发者后台创建 App
1.  登录 [App Store Connect](https://appstoreconnect.apple.com/)。
2.  进入“我的 App”，点击左上角 `+` 号选择 **“新建 App”**。
3.  填写基本信息：
    *   **平台**：iOS
    *   **名称**：江湖大侠（如果重名可以加后缀）
    *   **主要语言**：简体中文
    *   **套装 ID (Bundle ID)**：选择你 Xcode 项目中对应的 `com.weiyu.kx-game-ios`
    *   **SKU**：输入一个唯一的英文标识符（如 `kxgameios_v1`）
    *   **用户访问权限**：完全访问权限

### 2. 在 Xcode 中归档并上传
1.  在 Xcode 顶部设备栏，切换设备为 **`Any iOS Device (arm64)`**。
2.  点击顶部菜单栏 **Product -> Archive**（归档）。
3.  等待归档编译完成后，会弹出一个 **Organizer** 窗口。
4.  选中刚刚生成的 Archive，点击右侧的 **`Distribute App`**。
5.  选择 **`App Store Connect`** -> **`Upload`**（上传）。
6.  按照向导点击 **`Next`**，选择自动签名（Xcode 会自动生成生产证书）。
7.  上传成功后，通常会有 10~30 分钟的后台处理（Processing）时间。

### 3. 配置 TestFlight 内测
1.  回到 [App Store Connect](https://appstoreconnect.apple.com/) 的 App 管理页面。
2.  点击顶部导航栏的 **`TestFlight`**。
3.  在左侧栏选择 **`External Groups`（外部测试组）**，点击 `+` 新建一个测试组（如“江湖内测组”）。
4.  当上传的 Build 处理完毕后，在“构建版本”一栏添加你刚才上传的版本。
5.  在“外部测试”里，苹果会要求你进行简单的 beta 版审核说明（由于本 App 是纯 WebView 套壳，描述里写“主要测试网页渲染流畅度及基础操作响应”即可，不要提及私服或未授权的第三方内容以防被拒）。
6.  审核通过后，你会在外部测试组里获得一个 **“公共链接”（Public Link）**。
7.  把这个链接发给任何人，他们用 iPhone 打开链接就会引导下载 TestFlight 并直接安装“江湖大侠”App！
