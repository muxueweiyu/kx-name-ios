//
//  ViewController.swift
//  kx-name-ios
//
//  Created by moyu on 2026/7/17.
//

import UIKit
import WebKit
import AVFoundation

class ViewController: UIViewController, WKNavigationDelegate {
    var webView: WKWebView!
    var audioPlayer: AVAudioPlayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 1. 开启屏幕常亮 (防止挂机时熄屏)
        UIApplication.shared.isIdleTimerDisabled = true
        
        // 2. 激活后台无声音频挂活机制
        setupBackgroundAudioLoop()
        
        // 3. 创建并配置高性能 WKWebView 及其配置注入
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.allowsInlineMediaPlayback = true // 允许网页内播放视频(广告)
        
        // 注入防御与拦截自愈脚本：
        // 1. 高级原型链防护罩：在 PlatformAPI.updateData 为空时，防止读取 selectBins 和 exceptionUrl 触发 window.onerror 死循环。
        // 2. 状态码劫持拦截器：检测关键 JSON 配置文件因网络阻断导致返回 401/404/500 等非 200 响应，自动触发重载。
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

            var isReloading = false;
            function triggerSelfHealing() {
                if (isReloading) return;
                isReloading = true;
                console.log('【外壳注入】关键资源加载失败(非200或网络中断)，3秒后自动模拟 F5 执行热重载...');
                setTimeout(function() {
                    window.location.reload();
                }, 3000);
            }
            
            // 1. 劫持并监听 XMLHttpRequest.send (检测包括 401/404 在内的非 200 完成状态)
            var oldSend = XMLHttpRequest.prototype.send;
            XMLHttpRequest.prototype.send = function() {
                var xhr = this;
                var oldOnReadyStateChange = xhr.onreadystatechange;
                xhr.onreadystatechange = function() {
                    if (xhr.readyState === 4) {
                        // 如果请求完成，且状态码不是 200，并且请求的是 .json 配置文件，触发重载
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
            
            // 2. 劫持并监听 Fetch (检测非 ok 状态和捕获网络异常)
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
        let contentController = WKUserContentController()
        contentController.addUserScript(userScript)
        webConfiguration.userContentController = contentController
        
        // 4. 实例化全屏浏览器窗口 (自适应刘海屏和安全区域)
        webView = WKWebView(frame: self.view.bounds, configuration: webConfiguration)
        webView.navigationDelegate = self
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // 5. 将浏览器加入界面
        self.view.addSubview(webView)
        
        // 6. 载入游戏网页地址
        if let url = URL(string: "http://kx.hdhive.com/") {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    // 7. 隐藏顶部状态栏，实现完全沉浸式游戏画面
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    // 8. 处理网页主框架初步加载失败（如网络完全断开）
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
    
    // 9. 🛡️ 极客原语：动态生成无声 PCM 音频数据并循环播放，欺骗系统保持后台 JS 线程活跃
    private func setupBackgroundAudioLoop() {
        do {
            // 设置音频会话类别为 Playback 允许后台播放
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            
            // 动态生成一段 1秒 的极微小/无声 WAV 数据，避免引入外部文件
            let silentWAVData = createSilentWAVHeaderAndPCM()
            
            // 初始化音频播放器
            audioPlayer = try AVAudioPlayer(data: silentWAVData)
            audioPlayer?.numberOfLoops = -1 // 无限循环播放
            audioPlayer?.volume = 0.01      // 音量设为极小（接近静音，确保绝对不打扰用户）
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            print("【系统挂活】后台静音音频挂活服务启动成功，已开启锁屏/后台不挂起。")
        } catch {
            print("【系统挂活】音频挂活初始化失败: \(error.localizedDescription)")
        }
    }
    
    // 动态生成一个包含 WAV 头部和 1秒 零数据 PCM 的 Data 缓存 (静态常量数组，避免 Swift 数组切片类型赋值报错)
    private func createSilentWAVHeaderAndPCM() -> Data {
        let header: [UInt8] = [
            0x52, 0x49, 0x46, 0x46, // "RIFF"
            0xA4, 0x3E, 0x00, 0x00, // ChunkSize (16036)
            0x57, 0x41, 0x56, 0x45, // "WAVE"
            0x66, 0x6D, 0x74, 0x20, // "fmt "
            0x10, 0x00, 0x00, 0x00, // Subchunk1Size (16)
            0x01, 0x00,             // AudioFormat (1)
            0x01, 0x00,             // NumChannels (1)
            0x40, 0x1F, 0x00, 0x00, // SampleRate (8000)
            0x80, 0x3E, 0x00, 0x00, // ByteRate (16000)
            0x02, 0x00,             // BlockAlign (2)
            0x10, 0x00,             // BitsPerSample (16)
            0x64, 0x61, 0x74, 0x61, // "data"
            0x80, 0x3E, 0x00, 0x00  // Subchunk2Size (16000)
        ]
        var wavData = Data(header)
        let pcmDataSize = 16000 // 8000 采样率 * 2 字节(16位) * 1 秒
        let zeroSamples = [UInt8](repeating: 0, count: pcmDataSize)
        wavData.append(contentsOf: zeroSamples)
        return wavData
    }
}
