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
    }
    
    // 6. 隐藏顶部状态栏（电量、时间），实现完全沉浸式游戏画面
    override var prefersStatusBarHidden: Bool {
        return true
    }
}
