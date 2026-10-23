// WebContentView.swift
// SwiftUI-обёртка для показа единственного WKWebView во вкладке.
// Использует WebViewManager для доступа к единственному экземпляру WebAppViewController.

import SwiftUI

struct WebContentView: UIViewControllerRepresentable {
    let tab: TabItem
    @ObservedObject var webViewManager = WebViewManager.shared
    @EnvironmentObject var appLanguage: AppLanguage
    
    func makeUIViewController(context: Context) -> WebAppViewController {
        webViewManager.initialize(appLanguage: appLanguage)
        return webViewManager.viewController!
    }
    
    func updateUIViewController(_ controller: WebAppViewController, context: Context) {
        // Переключаем веб-приложение на эту вкладку
        webViewManager.selectTab(tab.webID)
    }
}
