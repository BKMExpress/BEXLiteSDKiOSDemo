//
//  LiteSDKTds.swift
//  bex-litesdk-demo
//

import BKMExpressLiteSDK
import Foundation
import WebKit
import UIKit
import SwiftUI
import Combine

enum LiteSDKTds {
  @MainActor
  final class ViewModel: ObservableObject {
    @Published var isLoading = false
    
    let token: BKMExpress.PaymentToken
    let api: BKMExpress.API
    let htmlForm: String
    let tdsURL: URL
    let onCompleted: (BKMExpress.ControlPaymentResponse) -> Void
    let onError: ((String) -> Void)?
    let onCancel: (() -> Void)?
    let enableAutoSubmit: Bool
    let allowWebViewHistoryBack: Bool
    var allowSslErrors: Bool
    let enableUrlLogging: Bool
    let logTag: String
    
    private(set) var didFinished = false
    private var hasCompleted = false
    private var hasAutoSubmittedInitialHtmlForm = false
    private var controlPaymentTask: Task<Void, Never>?
    
    init(
      token: BKMExpress.PaymentToken,
      api: BKMExpress.API,
      htmlForm: String,
      tdsURL: URL,
      onCompleted: @escaping (BKMExpress.ControlPaymentResponse) -> Void,
      onError: ((String) -> Void)? = nil,
      onCancel: (() -> Void)? = nil,
      enableAutoSubmit: Bool = true,
      allowWebViewHistoryBack: Bool = false,
      allowSslErrors: Bool = false,
      enableUrlLogging: Bool = true,
      logTag: String = "3DS-Parser"
    ) {
      self.token = token
      self.api = api
      self.htmlForm = htmlForm
      self.tdsURL = tdsURL
      self.onCompleted = onCompleted
      self.onError = onError
      self.onCancel = onCancel
      self.enableAutoSubmit = enableAutoSubmit
      self.allowWebViewHistoryBack = allowWebViewHistoryBack
      self.allowSslErrors = allowSslErrors
      self.enableUrlLogging = enableUrlLogging
      self.logTag = logTag
    }
    
    func markFinished() {
      didFinished = true
    }
    
    @discardableResult
    func checkCompletion(url: URL) -> Bool {
      guard !hasCompleted, didFinished else {
        return false
      }
      
      if isThreeDsFailureUrl(url) {
        log("3DS failure URL detected → url=\(url.absoluteString)", level: .error)
        fail("3DS failed")
        return true
      }
      
      guard isThreeDsCompletionUrl(url) else {
        return false
      }
      
      log("3DS completion URL detected → url=\(url.absoluteString)")
      hasCompleted = true
      isLoading = true
      
      controlPaymentTask = Task { [weak self] in
        guard let self else { return }
        
        do throws(BKMExpress.Failure) {
          let response = try await api.controlPayment(token: token, maxAttempts: 4)
          guard !Task.isCancelled else { return }
          self.onCompleted(response)
          
        } catch let error {
          guard !Task.isCancelled else { return }
          if error.isCancelled { return }
          self.isLoading = false
          self.onError?(error.message)
        }
      }
      
      return false
    }
    
    func shouldAutoSubmit() -> Bool {
      enableAutoSubmit && !htmlForm.isEmpty && !hasAutoSubmittedInitialHtmlForm && !hasCompleted
    }
    
    func markAutoSubmitted() {
      hasAutoSubmittedInitialHtmlForm = true
    }
    
    func fail(_ message: String) {
      guard !hasCompleted else { return }
      hasCompleted = true
      isLoading = false
      controlPaymentTask?.cancel()
      log(message, level: .error)
      onError?(message)
    }
    
    func failSSL() {
      fail("3DS SSL certificate error")
    }
    
    func bypassSSL() {
      log("3DS SSL error bypassed (allowSslErrors=true)", level: .warning)
    }
    
    func cancel() {
      controlPaymentTask?.cancel()
      isLoading = false
      onCancel?()
    }
    
    func handleDisappear() {
      guard !hasCompleted else { return }
      cancel()
    }
    
    deinit {
      controlPaymentTask?.cancel()
    }
    
    enum LogLevel { case debug, warning, error }
    
    func log(_ message: String, level: LogLevel = .debug) {
      guard enableUrlLogging else { return }
      switch level {
      case .debug:   print("[\(logTag)] \(message)")
      case .warning: print("[\(logTag)] Warning: \(message)")
      case .error:   print("[\(logTag)] Error: \(message)")
      }
    }
  }
  
  struct WebView: UIViewRepresentable {
    @ObservedObject var viewModel: ViewModel
    var mode: Mode
    
    func makeCoordinator() -> Coordinator {
      Coordinator(viewModel: viewModel)
    }
    
    func makeUIView(context: Context) -> WKWebView {
      let webView = WKWebView()
      webView.navigationDelegate = context.coordinator
      webView.uiDelegate = context.coordinator.uiDelegate
      context.coordinator.lastMode = mode
      load(into: webView)
      return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
      if context.coordinator.lastMode != mode {
        context.coordinator.lastMode = mode
        load(into: uiView)
      }
    }
    
    private func load(into webView: WKWebView) {
      if !viewModel.htmlForm.isEmpty {
        viewModel.log("3DS loading htmlForm via loadHTMLString — baseURL=\(viewModel.tdsURL.absoluteString) formLength=\(viewModel.htmlForm.count)")
        webView.loadHTMLString(viewModel.htmlForm, baseURL: viewModel.tdsURL)
      } else {
        viewModel.log("3DS loading tdsUrl directly — url=\(viewModel.tdsURL.absoluteString)")
        webView.load(URLRequest(url: viewModel.tdsURL))
      }
    }
  }
  
  final class Coordinator: NSObject, WKNavigationDelegate {
    let viewModel: ViewModel
    let uiDelegate: UIDelegate
    var lastMode: Mode?
    
    init(viewModel: ViewModel) {
      self.viewModel = viewModel
      self.uiDelegate = UIDelegate(viewModel: viewModel)
    }
    
    func webView(
      _ webView: WKWebView,
      decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
      guard let url = navigationAction.request.url else { return .cancel }
      viewModel.log("3DS decidePolicyFor url=\(url.absoluteString) navigationType=\(navigationAction.navigationType.rawValue)")
      if viewModel.checkCompletion(url: url) {
        return .cancel
      }
      return .allow
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
      guard let url = webView.url else { return }
      Task { @MainActor in
        viewModel.log("3DS didStartProvisionalNavigation url=\(url.absoluteString)")
        viewModel.checkCompletion(url: url)
      }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      guard let url = webView.url else { return }
      Task { @MainActor [weak webView] in
        viewModel.log("3DS didFinish url=\(url.absoluteString)")
        viewModel.markFinished()
        guard !viewModel.checkCompletion(url: url) else { return }
        guard let webView, viewModel.shouldAutoSubmit() else { return }
        viewModel.markAutoSubmitted()
        Self.runAutoSubmit(on: webView, viewModel: viewModel)
      }
    }
    
    func webView(
      _ webView: WKWebView,
      didFailProvisionalNavigation navigation: WKNavigation!,
      withError error: Error
    ) {
      let nsError = error as NSError
      guard nsError.code != NSURLErrorCancelled else { return }
      Task { @MainActor in
        viewModel.log("3DS didFailProvisionalNavigation code=\(nsError.code) description=\(nsError.localizedDescription)", level: .error)
        viewModel.fail(error.localizedDescription)
      }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
      let nsError = error as NSError
      guard nsError.code != NSURLErrorCancelled else { return }
      Task { @MainActor in
        viewModel.log("3DS didFail code=\(nsError.code) description=\(nsError.localizedDescription)", level: .error)
        viewModel.fail(error.localizedDescription)
      }
    }
    
    func webView(
      _ webView: WKWebView,
      didReceive challenge: URLAuthenticationChallenge,
      completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
      guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let trust = challenge.protectionSpace.serverTrust
      else {
        completionHandler(.performDefaultHandling, nil)
        return
      }
      Task { @MainActor in
        if viewModel.allowSslErrors {
          viewModel.bypassSSL()
          completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
          completionHandler(.cancelAuthenticationChallenge, nil)
          viewModel.failSSL()
        }
      }
    }
    
    @MainActor
    private static func runAutoSubmit(on webView: WKWebView, viewModel: ViewModel) {
      let js = """
            (function () {
                try {
                    if (window.__bexAutoSubmitted) { return 'already_submitted'; }
                    window.__bexAutoSubmitted = true;
                    var script = document.createElement('script');
                    script.innerHTML = `
                        (function() {
                            var form = document.forms['bkmForm'] || document.forms[0];
                            if (!form) { console.log('no_form'); return; }
                            form.submit();
                            console.log('submitted');
                        })();
                    `;
                    document.head.appendChild(script);
                    return 'script_injected';
                } catch (e) {
                    return 'error:' + e.message;
                }
            })();
            """
      webView.evaluateJavaScript(js) { result, error in
        viewModel.log("3DS JS auto-submit result=\(result ?? "nil") error=\(error?.localizedDescription ?? "nil")")
      }
    }
  }
  
  final class UIDelegate: NSObject, WKUIDelegate {
    private let viewModel: ViewModel
    
    init(viewModel: ViewModel) {
      self.viewModel = viewModel
    }
    
    func webView(
      _ webView: WKWebView,
      runJavaScriptConfirmPanelWithMessage message: String,
      initiatedByFrame frame: WKFrameInfo
    ) async -> Bool {
      await withCheckedContinuation { continuation in
        Task { @MainActor in
          self.viewModel.log("3DS JS confirm panel message=\(message)")
          guard let presenter = webView.window?.rootViewController?.topPresented else {
            continuation.resume(returning: false)
            return
          }
          let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
          alert.addAction(UIAlertAction(title: "Hayır", style: .cancel) { _ in
            continuation.resume(returning: false)
          })
          alert.addAction(UIAlertAction(title: "Evet", style: .default) { _ in
            continuation.resume(returning: true)
          })
          presenter.present(alert, animated: true)
        }
      }
    }
    
    func webView(
      _ webView: WKWebView,
      runJavaScriptAlertPanelWithMessage message: String,
      initiatedByFrame frame: WKFrameInfo
    ) async {
      await withCheckedContinuation { continuation in
        Task { @MainActor in
          self.viewModel.log("3DS JS alert panel message=\(message)")
          guard let presenter = webView.window?.rootViewController?.topPresented else {
            continuation.resume()
            return
          }
          let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
          alert.addAction(UIAlertAction(title: "Tamam", style: .default) { _ in
            continuation.resume()
          })
          presenter.present(alert, animated: true)
        }
      }
    }
    
    func webView(
      _ webView: WKWebView,
      runJavaScriptTextInputPanelWithPrompt prompt: String,
      defaultText: String?,
      initiatedByFrame frame: WKFrameInfo
    ) async -> String? {
      await withCheckedContinuation { continuation in
        Task { @MainActor in
          self.viewModel.log("3DS JS prompt panel prompt=\(prompt)")
          guard let presenter = webView.window?.rootViewController?.topPresented else {
            continuation.resume(returning: nil)
            return
          }
          let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
          alert.addTextField { $0.text = defaultText }
          alert.addAction(UIAlertAction(title: "Hayır", style: .cancel) { _ in
            continuation.resume(returning: nil)
          })
          alert.addAction(UIAlertAction(title: "Evet", style: .default) { _ in
            continuation.resume(returning: alert.textFields?.first?.text)
          })
          presenter.present(alert, animated: true)
        }
      }
    }
  }
  
  struct Screen: View {
    @AppStorage("mode") private var mode: Mode = .default
    @StateObject private var viewModel: ViewModel
    
    init(
      token: BKMExpress.PaymentToken,
      api: BKMExpress.API,
      htmlForm: String,
      tdsURL: URL,
      onCompleted: @escaping (BKMExpress.ControlPaymentResponse) -> Void,
      onError: ((String) -> Void)? = nil,
      onCancel: (() -> Void)? = nil,
      enableAutoSubmit: Bool = true,
      allowWebViewHistoryBack: Bool = false,
      allowSslErrors: Bool = false,
      enableUrlLogging: Bool = true,
      logTag: String = "3DS-Parser"
    ) {
      _viewModel = StateObject(wrappedValue: ViewModel(
        token: token,
        api: api,
        htmlForm: htmlForm,
        tdsURL: tdsURL,
        onCompleted: onCompleted,
        onError: onError,
        onCancel: onCancel,
        enableAutoSubmit: enableAutoSubmit,
        allowWebViewHistoryBack: allowWebViewHistoryBack,
        allowSslErrors: allowSslErrors,
        enableUrlLogging: enableUrlLogging,
        logTag: logTag
      ))
    }
    
    var body: some View {
      ZStack {
        WebView(viewModel: viewModel, mode: mode)
          .ignoresSafeArea(edges: .bottom)
        
        if viewModel.isLoading {
          ZStack {
            Rectangle().fill(.regularMaterial)
            VStack(spacing: 12) {
              ProgressView()
                .controlSize(.large)
              Text("Ödeme kontrol ediliyor...")
            }
          }
          .ignoresSafeArea()
        }
      }
      .navigationTitle("İşlem Doğrulama")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("İptal") {
            viewModel.cancel()
          }
        }
      }
      .onDisappear {
        viewModel.handleDisappear()
      }
    }
  }
}

private let completionPathRegex: NSRegularExpression = {
  try! NSRegularExpression(pattern: #"(?i)(?:^|/)resultUrl/[^/?#]+/bex(?:/|$)"#)
}()

private let failurePathRegex: NSRegularExpression = {
  try! NSRegularExpression(pattern: #"(?i)(?:^|/)resultUrl/failure(?:/|$)"#)
}()

private func isThreeDsCompletionUrl(_ url: URL) -> Bool {
  let candidate = url.path
  guard !candidate.isEmpty else { return false }
  let range = NSRange(candidate.startIndex..., in: candidate)
  return completionPathRegex.firstMatch(in: candidate, range: range) != nil
}

private func isThreeDsFailureUrl(_ url: URL) -> Bool {
  let candidate = url.path
  guard !candidate.isEmpty else { return false }
  let range = NSRange(candidate.startIndex..., in: candidate)
  return failurePathRegex.firstMatch(in: candidate, range: range) != nil
}

private extension UIViewController {
  var topPresented: UIViewController {
    presentedViewController?.topPresented ?? self
  }
}
