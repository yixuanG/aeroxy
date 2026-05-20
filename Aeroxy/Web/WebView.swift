import AppKit
import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    @ObservedObject var tab: HTMLTab
    let printRequestID: UUID
    let openFileInNewTab: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.suppressesIncrementalRendering = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsMagnification = true
        webView.allowsBackForwardNavigationGestures = false
        webView.underPageBackgroundColor = .clear
        context.coordinator.load(tab: tab, in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.load(tab: tab, in: webView)
        context.coordinator.printIfRequested(webView)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebView
        private var loadedTabID: HTMLTab.ID?
        private var loadedFileURL: URL?
        private var handledPrintRequestID: UUID

        init(parent: WebView) {
            self.parent = parent
            self.handledPrintRequestID = parent.printRequestID
        }

        func load(tab: HTMLTab, in webView: WKWebView) {
            let fileURL = tab.fileURL.standardizedFileURL

            guard loadedTabID != tab.id || loadedFileURL != fileURL else {
                return
            }

            loadedTabID = tab.id
            loadedFileURL = fileURL
            tab.loadError = nil
            webView.loadFileURL(fileURL, allowingReadAccessTo: tab.readAccessURL)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            if navigationAction.shouldPerformDownload {
                decisionHandler(.cancel)
                return
            }

            if navigationAction.targetFrame == nil {
                openNewWindowURL(url)
                decisionHandler(.cancel)
                return
            }

            if navigationAction.targetFrame?.isMainFrame == true {
                if URLPolicy.isOpenableLocalHTML(url),
                   url.standardizedFileURL.path != parent.tab.fileURL.path {
                    parent.openFileInNewTab(url)
                    decisionHandler(.cancel)
                    return
                }

                if url.isFileURL, !URLPolicy.isOpenableLocalHTML(url) {
                    NSWorkspace.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }

                if URLPolicy.isExternalMainFrameURL(url) {
                    NSWorkspace.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
            }

            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationResponsePolicy) -> Void
        ) {
            guard navigationResponse.isForMainFrame else {
                decisionHandler(.allow)
                return
            }

            guard navigationResponse.canShowMIMEType else {
                decisionHandler(.cancel)
                return
            }

            let disposition = (navigationResponse.response as? HTTPURLResponse)?
                .value(forHTTPHeaderField: "Content-Disposition")?
                .lowercased()

            if disposition?.contains("attachment") == true {
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard let url = navigationAction.request.url else {
                return nil
            }

            openNewWindowURL(url)
            return nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            updateTitle(from: webView)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            report(error)
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            report(error)
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping @MainActor @Sendable () -> Void
        ) {
            completionHandler()
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping @MainActor @Sendable (Bool) -> Void
        ) {
            completionHandler(false)
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptTextInputPanelWithPrompt prompt: String,
            defaultText: String?,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping @MainActor @Sendable (String?) -> Void
        ) {
            completionHandler(nil)
        }

        func webView(
            _ webView: WKWebView,
            runOpenPanelWith parameters: WKOpenPanelParameters,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping @MainActor @Sendable ([URL]?) -> Void
        ) {
            completionHandler(nil)
        }

        func webView(
            _ webView: WKWebView,
            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
            initiatedByFrame frame: WKFrameInfo,
            type: WKMediaCaptureType,
            decisionHandler: @escaping @MainActor @Sendable (WKPermissionDecision) -> Void
        ) {
            decisionHandler(.deny)
        }

        func printIfRequested(_ webView: WKWebView) {
            guard handledPrintRequestID != parent.printRequestID else {
                return
            }

            handledPrintRequestID = parent.printRequestID
            webView.printOperation(with: NSPrintInfo.shared).run()
        }

        private func openNewWindowURL(_ url: URL) {
            if url.isFileURL {
                parent.openFileInNewTab(url)
            } else {
                NSWorkspace.shared.open(url)
            }
        }

        private func updateTitle(from webView: WKWebView) {
            webView.evaluateJavaScript("document.title") { [weak self] value, _ in
                guard let self else {
                    return
                }

                let title = (value as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard let title, !title.isEmpty else {
                    return
                }

                Task { @MainActor in
                    self.parent.tab.title = title
                }
            }
        }

        private func report(_ error: Error) {
            let nsError = error as NSError

            guard nsError.code != NSURLErrorCancelled else {
                return
            }

            parent.tab.loadError = nsError.localizedDescription
        }
    }
}
