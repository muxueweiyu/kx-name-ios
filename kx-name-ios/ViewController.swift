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
    
    // 动态生成一个包含 WAV 头部和 1秒 零数据 PCM 的 Data 缓存
    private func createSilentWAVHeaderAndPCM() -> Data {
        let sampleRate: Int32 = 8000
        let channels: Int16 = 1
        let bitsPerSample: Int16 = 16
        let duration: Int = 1 // 1秒无声
        
        let pcmDataSize = Int(sampleRate) * Int(channels) * (Int(bitsPerSample) / 8) * duration
        let headerSize = 44
        var header = [UInt8](repeating: 0, count: headerSize)
        
        // RIFF header
        header[0...3] = Array("RIFF".utf8)
        let fileSize = Int32(pcmDataSize + headerSize - 8)
        let fileSizeArray = withUnsafeBytes(of: fileSize) { Array($0) }
        header[4...7] = fileSizeArray[0...3]
        header[8...11] = Array("WAVE".utf8)
        
        // fmt chunk
        header[12...15] = Array("fmt ".utf8)
        let subchunk1Size: Int32 = 16
        let subchunk1SizeArray = withUnsafeBytes(of: subchunk1Size) { Array($0) }
        header[16...19] = subchunk1SizeArray[0...3]
        
        let audioFormat: Int16 = 1 // PCM
        let audioFormatArray = withUnsafeBytes(of: audioFormat) { Array($0) }
        header[20...21] = audioFormatArray[0...1]
        
        let channelsArray = withUnsafeBytes(of: channels) { Array($0) }
        header[22...23] = channelsArray[0...1]
        
        let sampleRateArray = withUnsafeBytes(of: sampleRate) { Array($0) }
        header[24...27] = sampleRateArray[0...3]
        
        let byteRate = sampleRate * Int32(channels) * Int32(bitsPerSample / 8)
        let byteRateArray = withUnsafeBytes(of: byteRate) { Array($0) }
        header[28...31] = byteRateArray[0...3]
        
        let blockAlign = channels * (bitsPerSample / 8)
        let blockAlignArray = withUnsafeBytes(of: blockAlign) { Array($0) }
        header[32...33] = blockAlignArray[0...1]
        
        let bitsPerSampleArray = withUnsafeBytes(of: bitsPerSample) { Array($0) }
        header[34...35] = bitsPerSampleArray[0...1]
        
        // data chunk
        header[36...39] = Array("data".utf8)
        let pcmDataSizeInt32 = Int32(pcmDataSize)
        let pcmDataSizeArray = withUnsafeBytes(of: pcmDataSizeInt32) { Array($0) }
        header[40...43] = pcmDataSizeArray[0...3]
        
        var wavData = Data(header)
        // 填充 1秒 的无声零数据
        let zeroSamples = [Int16](repeating: 0, count: pcmDataSize / 2)
        zeroSamples.withUnsafeBytes {
            wavData.append($0)
        }
        
        return wavData
    }
}
