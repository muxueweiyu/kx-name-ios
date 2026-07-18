//
//  ViewController.swift
//  kx-name-ios
//
//  Created by moyu on 2026/7/17.
//

import UIKit
import WebKit
import AVFoundation

class ViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    var webView: WKWebView!
    var audioPlayer: AVAudioPlayer?
    var backgroundTimer: Timer?
    var forgeButton: UIButton!
    var isForging = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 1. 开启屏幕常亮 (防止前台挂机时熄屏)
        UIApplication.shared.isIdleTimerDisabled = true
        
        // 2. 激活宿主 App 后台无声音频挂活
        setupBackgroundAudioLoop()
        
        // 3. 启动后台定时心跳注入，强行唤醒 WebContent 进程的 JS 引擎
        startBackgroundWakeupTimer()
        
        // 4. 创建并配置高性能 WKWebView 及其配置注入
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.allowsInlineMediaPlayback = true // 允许网页内播放视频(广告)
        
        // 苹果私有 API：安全探测并强行开启配置的 ForegroundPriority 属性，强制 WebKit 保持前台计算优先级
        if webConfiguration.responds(to: Selector(("alwaysRunsAtForegroundPriority"))) {
            webConfiguration.setValue(true, forKey: "alwaysRunsAtForegroundPriority")
            print("【系统挂活】成功激活 webConfiguration 级别的前台优先级。")
        }
        
        // 注册控制台日志转发接收器，使锁屏时的 console.log 能打印到 Xcode 控制台
        let contentController = WKUserContentController()
        contentController.add(self, name: "consoleLog")
        
        // 注入双端自愈与网页 HTML5 Audio 挂活脚本
        let hijackJS = """
        (function() {
            // 🛡️ 高级原型链防护罩：彻底防范错误上报器在配置未载入时的 TypeError 爆栈
            try {
                Object.defineProperty(Object.prototype, 'selectBins', {
                    value: [{ sdkb: "*", sdks: "*", bver: "*", loginUrl: "/api/", exceptionUrl: "" }],
                    writable: true,
                    configurable: true
                });
                Object.defineProperty(Object.prototype, 'exceptionUrl', {
                    value: '',
                    writable: true,
                    configurable: true
                });
                console.log('【外壳注入】高级原型链防护罩部署成功。');
            } catch (e) {
                console.error('【外壳注入】高级原型链防护罩部署失败:', e);
            }



            // 2. 日志拦截器：将 console 日志实时投递给宿主 App (Xcode 终端)，确保锁屏时可见
            var oldLog = console.log;
            console.log = function() {
                var message = Array.from(arguments).map(String).join(' ');
                oldLog.apply(console, arguments);
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.consoleLog) {
                    window.webkit.messageHandlers.consoleLog.postMessage('[LOG] ' + message);
                }
            };
            var oldErr = console.error;
            console.error = function() {
                var message = Array.from(arguments).map(String).join(' ');
                oldErr.apply(console, arguments);
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.consoleLog) {
                    window.webkit.messageHandlers.consoleLog.postMessage('[ERROR] ' + message);
                }
            };

            var isReloading = false;
            function triggerSelfHealing() {
                if (isReloading) return;
                isReloading = true;
                console.log('【外壳注入】关键资源加载失败(非200或网络中断)，3秒后自动模拟 F5 执行热重载...');
                setTimeout(function() {
                    window.location.reload();
                }, 3000);
            }
            
            // 3. 劫持并监听 XMLHttpRequest.send (检测包括 401/404 在内的非 200 完成状态)
            var oldSend = XMLHttpRequest.prototype.send;
            XMLHttpRequest.prototype.send = function() {
                var xhr = this;
                var oldOnReadyStateChange = xhr.onreadystatechange;
                xhr.onreadystatechange = function() {
                    if (xhr.readyState === 4) {
                        if (xhr.status !== 200 && xhr.responseURL && xhr.responseURL.indexOf('.json') !== -1) {
                            triggerSelfHealing();
                        }
                    }
                    if (oldOnReadyStateChange) {
                        oldOnReadyStateChange.apply(this, arguments);
                    }
                };
                oldSend.apply(this, arguments);
            };
            
            // 4. 劫持并监听 Fetch (检测非 ok 状态 and 捕获网络异常)
            var oldFetch = window.fetch;
            if (oldFetch) {
                window.fetch = function(input, init) {
                    return oldFetch(input, init).then(function(response) {
                        var url = typeof input === 'string' ? input : (input.url || '');
                        if (!response.ok && url && url.indexOf('.json') !== -1) {
                            triggerSelfHealing();
                        }
                        return response;
                    }).catch(function(err) {
                        var url = typeof input === 'string' ? input : (input.url || '');
                        if (url && url.indexOf('.json') !== -1) {
                            triggerSelfHealing();
                        }
                        throw err;
                    });
                };
            }
        })();
        """
        
        let userScript = WKUserScript(source: hijackJS, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        contentController.addUserScript(userScript)
        webConfiguration.userContentController = contentController
        
        // 5. 实例化全屏浏览器窗口 (自适应安全区域)
        webView = WKWebView(frame: self.view.bounds, configuration: webConfiguration)
        webView.navigationDelegate = self
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // 苹果私有 API：安全探测并强行开启 webView 级别的前台优先级，防止后台被降频暂停
        if webView.responds(to: Selector(("_alwaysRunsAtForegroundPriority"))) {
            webView.setValue(true, forKey: "_alwaysRunsAtForegroundPriority")
            print("【系统挂活】成功激活 webView _alwaysRunsAtForegroundPriority。")
        } else if webView.responds(to: Selector(("alwaysRunsAtForegroundPriority"))) {
            webView.setValue(true, forKey: "alwaysRunsAtForegroundPriority")
            print("【系统挂活】成功激活 webView alwaysRunsAtForegroundPriority。")
        }
        
        // 6. 将浏览器加入界面
        self.view.addSubview(webView)
        
        // 7. 载入游戏网页地址
        if let url = URL(string: "http://kx.hdhive.com/") {
            let request = URLRequest(url: url)
            webView.load(request)
        }
        
        // 7.5. 初始化悬浮智能挂机按钮
        setupFloatingControl()
    }
    
    // 8. 隐藏状态栏
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    // 9. 接收来自网页 JavaScript 转发过来的日志并打印在 Xcode 终端
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "consoleLog", let logString = message.body as? String {
            print("📱 [JS Console] \(logString)")
        }
    }
    
    // 10. 处理网页主框架加载失败
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("【网络监控】主网页初步加载失败: \(error.localizedDescription)，3秒后自动尝试重新连接...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.webView.load(URLRequest(url: URL(string: "http://kx.hdhive.com/")!))
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("【网络监控】主网页渲染加载失败: \(error.localizedDescription)，3秒后自动尝试重新连接...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.webView.load(URLRequest(url: URL(string: "http://kx.hdhive.com/")!))
        }
    }
    
    // 11. 🛡️ 宿主 App 无音轨 WAV 后台挂活
    private func setupBackgroundAudioLoop() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            
            let silentWAVData = createSilentWAVHeaderAndPCM()
            audioPlayer = try AVAudioPlayer(data: silentWAVData)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = 0.01
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            print("【系统挂活】宿主音频环路启动成功。")
        } catch {
            print("【系统挂活】音频挂活初始化失败: \(error.localizedDescription)")
        }
    }
    
    // 12. 🛡️ 宿主后台主动定时心跳注入，强行驱动 WebKit 引擎
    private func startBackgroundWakeupTimer() {
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // 12.1. 后台心跳维持并触发网页 autoPulse 驱动
                self.webView.evaluateJavaScript("if (window.autoPulse) { window.autoPulse(); } else if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.consoleLog) { window.webkit.messageHandlers.consoleLog.postMessage('[ACTIVE HEARTBEAT] Keep-Alive Tick'); }", completionHandler: nil)
                
                // 12.2. 动态检测玩家是否已登录进入主界面，以此决定是否渐显显示悬浮挂机按钮
                let checkLoginJS = """
                (function() {
                    try {
                        if (typeof System !== 'undefined') {
                            var m = System.get('chunks:///_virtual/GameServerData.ts');
                            if (m && m.GameServerData && m.GameServerData.getInstance()) {
                                var info = m.GameServerData.getInstance().fullInfo;
                                return info ? true : false;
                            }
                        }
                    } catch(e) {}
                    return false;
                })()
                """
                self.webView.evaluateJavaScript(checkLoginJS) { [weak self] (result, error) in
                    guard let self = self, let button = self.forgeButton else { return }
                    let isLoggedIn = (result as? Bool) ?? false
                    
                    if isLoggedIn {
                        // 登录成功：如果当前是隐藏状态，执行渐显动画显示按钮
                        if button.isHidden {
                            button.isHidden = false
                            button.alpha = 0.0
                            UIView.animate(withDuration: 0.4) {
                                button.alpha = 1.0
                            }
                        }
                    } else {
                        // 未登录或重连：如果当前是显示状态，执行渐隐动画隐藏按钮
                        if !button.isHidden {
                            UIView.animate(withDuration: 0.4, animations: {
                                button.alpha = 0.0
                            }) { _ in
                                button.isHidden = true
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func createSilentWAVHeaderAndPCM() -> Data {
        let header: [UInt8] = [
            0x52, 0x49, 0x46, 0x46,
            0xA4, 0x3E, 0x00, 0x00,
            0x57, 0x41, 0x56, 0x45,
            0x66, 0x6D, 0x74, 0x20,
            0x10, 0x00, 0x00, 0x00,
            0x01, 0x00,
            0x01, 0x00,
            0x40, 0x1F, 0x00, 0x00,
            0x80, 0x3E, 0x00, 0x00,
            0x02, 0x00,
            0x10, 0x00,
            0x64, 0x61, 0x74, 0x61,
            0x80, 0x3E, 0x00, 0x00
        ]
        var wavData = Data(header)
        let pcmDataSize = 16000
        let zeroSamples = [UInt8](repeating: 0, count: pcmDataSize)
        wavData.append(contentsOf: zeroSamples)
        return wavData
    }
    
    // 13. 初始化悬浮智能控制台按钮
    private func setupFloatingControl() {
        let button = UIButton(type: .custom)
        button.frame = CGRect(x: self.view.bounds.width - 160, y: 60, width: 140, height: 40)
        button.autoresizingMask = [.flexibleLeftMargin, .flexibleBottomMargin]
        
        button.setTitle("后台钓鱼: 关", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        button.layer.cornerRadius = 20
        button.layer.borderWidth = 1.5
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = button.bounds
        blurView.layer.cornerRadius = 20
        blurView.clipsToBounds = true
        blurView.isUserInteractionEnabled = false
        button.insertSubview(blurView, at: 0)
        
        button.addTarget(self, action: #selector(toggleForge), for: .touchUpInside)
        
        // 🚀 添加拖拽手势，使按钮可以被任意拖动，防止遮挡游戏 UI
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        button.addGestureRecognizer(panGesture)
        
        // 初始状态下按钮隐蔽隐藏，等登录成功后再显现
        button.isHidden = true
        button.alpha = 0.0
        
        self.view.addSubview(button)
        self.forgeButton = button
    }
    
    // 🚀 手势拖拽回调：带有屏幕边缘限制，防止拖出屏幕之外
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard let button = gesture.view as? UIButton else { return }
        let translation = gesture.translation(in: self.view)
        
        var newCenter = CGPoint(x: button.center.x + translation.x, y: button.center.y + translation.y)
        
        let margin: CGFloat = 16
        let minX = margin + button.frame.width / 2
        let maxX = self.view.bounds.width - margin - button.frame.width / 2
        let minY = 60.0 + button.frame.height / 2 // 避开顶部状态栏和灵动岛区域
        let maxY = self.view.bounds.height - margin - button.frame.height / 2
        
        newCenter.x = max(minX, min(maxX, newCenter.x))
        newCenter.y = max(minY, min(maxY, newCenter.y))
        
        button.center = newCenter
        gesture.setTranslation(.zero, in: self.view)
        
        // 拖动时临时断开自动约束定位
        button.autoresizingMask = []
    }
    
    @objc private func toggleForge() {
        // 先检测网页中是否已经注入了我们的挂机函数
        webView.evaluateJavaScript("typeof window.batchSmartForge !== 'undefined'") { [weak self] (result, error) in
            guard let self = self else { return }
            
            let isAlreadyInjected = (result as? Bool) ?? false
            
            if self.isForging {
                // 状态1：当前正在挂机中，用户点击按钮表示要【停止】
                self.isForging = false
                self.webView.evaluateJavaScript("window.stopBatchForge()") { (result, error) in
                    if let error = error {
                        print("【外壳控制】停止后台钓鱼失败: \(error.localizedDescription)")
                    } else {
                        print("【外壳控制】已停止后台钓鱼。")
                    }
                    self.forgeButton.setTitle("后台钓鱼: 关", for: .normal)
                    self.forgeButton.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
                }
            } else {
                // 状态2：当前未挂机，用户点击按钮表示要【开启】
                self.isForging = true
                
                if isAlreadyInjected {
                    // 如果已经注入过了，直接运行
                    self.executeStartForge()
                } else {
                    // 如果还没有注入过，先从 Bundle 加载并注入，然后再运行
                    self.injectHackerJS { [weak self] success in
                        if success {
                            self?.executeStartForge()
                        } else {
                            self?.isForging = false
                        }
                    }
                }
            }
        }
    }
    
    private func executeStartForge() {
        webView.evaluateJavaScript("window.batchSmartForge(1)") { [weak self] (result, error) in
            guard let self = self else { return }
            if let error = error {
                print("【外壳控制】启动后台钓鱼失败: \(error.localizedDescription)")
                self.isForging = false
                self.forgeButton.setTitle("后台钓鱼: 关", for: .normal)
                self.forgeButton.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
            } else {
                print("【外壳控制】已开启后台钓鱼。")
                self.forgeButton.setTitle("后台钓鱼: 开 🟢", for: .normal)
                self.forgeButton.layer.borderColor = UIColor.green.cgColor
            }
        }
    }
    
    private func injectHackerJS(completion: @escaping (Bool) -> Void) {
        print("【挂机初始化】检测到挂机脚本尚未注入，开始从 Bundle 读取 hacker_init.js...")
        if let filepath = Bundle.main.path(forResource: "hacker_init", ofType: "js"),
           let jsContent = try? String(contentsOfFile: filepath, encoding: .utf8) {
            
            webView.evaluateJavaScript(jsContent) { (result, error) in
                if let error = error {
                    print("【挂机初始化】hacker_init.js 注入失败: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("【挂机初始化】hacker_init.js 注入成功！")
                    completion(true)
                }
            }
        } else {
            print("⚠️【挂机初始化】未能在 Bundle 中找到 hacker_init.js 文件！请确保已将 hacker_init.js 拖入 Xcode 导航栏并勾选 Target Membership。")
            completion(false)
        }
    }

    // 14. 网页加载完成代理：重载或首次打开时，仅重置按钮状态，不进行默认注入
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("【网页加载】游戏网页加载/刷新完成。")
        self.isForging = false
        self.forgeButton.setTitle("后台钓鱼: 关", for: .normal)
        self.forgeButton.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
    }
}
