//
//  ViewController.swift
//  kx-name-ios
//
//  Created by moyu on 2026/7/17.
//

import UIKit
import WebKit

class ViewController: UIViewController, WKNavigationDelegate {
    var webView: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 1. 开启屏幕常亮 (防止挂机时熄屏)
        UIApplication.shared.isIdleTimerDisabled = true
        
        // 2. 创建并配置高性能 WKWebView 及其配置注入
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.allowsInlineMediaPlayback = true // 允许网页内播放视频(广告)
        
        // 注入防御与拦截自愈脚本：
        // 包含原型链防护罩（防止 updateData 未定义时报错上报死循环）和 AJAX/Fetch 拦截重试
        let hijackJS = """
        (function() {
            // 🛡️ 原型链防护罩：防止 PlatformAPI.updateData 未定义时读取 exceptionUrl 触发 window.onerror 套娃死循环
            try {
                Object.defineProperty(Object.prototype, 'updateData', {
                    value: { exceptionUrl: '', buyQuantity: [], images: [], selectBins: [] },
                    writable: true,
                    configurable: true
                });
                console.log('【外壳注入】原型链防护罩部署成功。');
            } catch (e) {
                console.error('【外壳注入】原型链防护罩部署失败:', e);
            }

            var isReloading = false;
            function triggerSelfHealing() {
                if (isReloading) return;
                isReloading = true;
                console.log('【外壳注入】关键资源加载失败，3秒后自动尝试重新热重载...');
                setTimeout(function() {
                    window.location.reload();
                }, 3000);
            }
            
            // 1. 劫持并监听 XMLHttpRequest
            var oldOpen = XMLHttpRequest.prototype.open;
            XMLHttpRequest.prototype.open = function(method, url) {
                this.addEventListener('error', function() {
                    if (url && url.indexOf('.json') !== -1) {
                        triggerSelfHealing();
                    }
                });
                oldOpen.apply(this, arguments);
            };
            
            // 2. 劫持并监听 Fetch
            var oldFetch = window.fetch;
            if (oldFetch) {
                window.fetch = function(input, init) {
                    return oldFetch(input, init).catch(function(err) {
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
        
        // 3. 实例化全屏浏览器窗口 (自适应刘海屏和安全区域)
        webView = WKWebView(frame: self.view.bounds, configuration: webConfiguration)
        webView.navigationDelegate = self
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // 4. 将浏览器加入界面
        self.view.addSubview(webView)
        
        // 5. 载入游戏网页地址
        if let url = URL(string: "http://kx.hdhive.com/") {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    // 6. 隐藏顶部状态栏，实现完全沉浸式游戏画面
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    // 7. 处理网页主框架初步加载失败（如网络完全断开）
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
}
