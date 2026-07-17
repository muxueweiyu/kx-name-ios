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
    var watchdogTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 1. 开启屏幕常亮 (防止挂机时熄屏)
        UIApplication.shared.isIdleTimerDisabled = true
        
        // 2. 创建并配置高性能 WKWebView
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.allowsInlineMediaPlayback = true // 允许网页内播放视频(广告)
        
        // 3. 实例化全屏浏览器窗口 (自适应刘海屏和安全区域)
        webView = WKWebView(frame: self.view.bounds, configuration: webConfiguration)
        webView.navigationDelegate = self
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // 4. 将浏览器加入界面
        self.view.addSubview(webView)
        
        // 5. 载入游戏网页地址 (加载我们抓包的那个主要游戏网页地址)
        if let url = URL(string: "http://kx.hdhive.com/") {
            let request = URLRequest(url: url)
            webView.load(request)
        }
        
        // 6. 开启冷启动卡死监控定时器 (8秒超时自动重载)
        startWatchdogTimer()
    }
    
    // 7. 隐藏顶部状态栏（电量、时间），实现完全沉浸式游戏画面
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    // 8. 开启看门狗定时器
    private func startWatchdogTimer() {
        watchdogTimer?.invalidate()
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
            self?.checkGameLoadingStatus()
        }
    }
    
    // 9. 校验游戏加载状态，如果死锁则重载
    private func checkGameLoadingStatus() {
        // 通过 JS 检查 Cocos Creator 引擎是否成功运行且场景正常载入
        webView.evaluateJavaScript("window.cc !== undefined && window.cc.director !== undefined && window.cc.director.getScene() !== null") { [weak self] (result, error) in
            guard let self = self else { return }
            if let isLoaded = result as? Bool, isLoaded {
                print("【自检监控】Cocos 引擎已成功运行，解除看门狗。")
            } else {
                print("【自检监控】检测到冷启动死锁或载入超时，正在强行执行网页热重载...")
                self.webView.reload()
                // 重新启动一轮定时器，防止连续卡死
                self.startWatchdogTimer()
            }
        }
    }
    
    // 10. 处理网页加载失败（如首次启动网络权限弹窗导致的安全阻断）
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("【网络监控】网页初步加载失败: \(error.localizedDescription)，3秒后自动尝试重新连接...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.webView.load(URLRequest(url: URL(string: "http://kx.hdhive.com/")!))
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("【网络监控】网页渲染加载失败: \(error.localizedDescription)，3秒后自动尝试重新连接...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.webView.load(URLRequest(url: URL(string: "http://kx.hdhive.com/")!))
        }
    }
    
    deinit {
        watchdogTimer?.invalidate()
    }
}
