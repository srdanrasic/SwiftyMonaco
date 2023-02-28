//
//  MonacoViewController.swift
//  
//
//  Created by Pavel Kasila on 20.03.21.
//

#if os(macOS)
import AppKit
public typealias ViewController = NSViewController
#else
import UIKit
public typealias ViewController = UIViewController
#endif
import WebKit

public class MonacoViewController: ViewController, WKUIDelegate, WKNavigationDelegate {
    
    var delegate: MonacoViewControllerDelegate?
    
    var webView: WKWebView!
    
    public override func loadView() {
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.userContentController.add(UpdateTextScriptHandler(self), name: "updateText")
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        #if os(iOS)
        webView.backgroundColor = .none
        #else
        webView.layer?.backgroundColor = NSColor.clear.cgColor
        #endif
        view = webView
        #if os(macOS)
        DistributedNotificationCenter.default.addObserver(self, selector: #selector(interfaceModeChanged(sender:)), name: NSNotification.Name(rawValue: "AppleInterfaceThemeChangedNotification"), object: nil)
        #endif
    }
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        loadMonaco()
    }
    
    private func loadMonaco() {
        let myURL = Bundle.module.url(forResource: "index", withExtension: "html", subdirectory: "Monaco")
        let myRequest = URLRequest(url: myURL!)
        webView.load(myRequest)
    }
    
    // MARK: - Dark Mode
    private func updateTheme() {
        evaluateJavascript("""
        (function(){
            monaco.editor.setTheme('\(detectTheme())')
        })()
        """)
    }
    
    #if os(macOS)
    @objc private func interfaceModeChanged(sender: NSNotification) {
        updateTheme()
    }
    #else
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateTheme()
    }
    #endif
    
    private func detectTheme() -> String {
        #if os(macOS)
        if UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark" {
            return "vs-dark"
        } else {
            return "vs"
        }
        #else
        switch traitCollection.userInterfaceStyle {
            case .light, .unspecified:
                return "vs"
            case .dark:
                return "vs-dark"
            @unknown default:
                return "vs"
        }
        #endif
    }
    
    // MARK: - WKWebView
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Code itself
        var text = self.delegate?.monacoView(readText: self) ?? ""
        if #available(macOS 13.0, *) {
            text.replace("\\", with: "\\\\")
        }
        let javascript =
        """
        editor.getModel().setValue('\(text)');
        editor.getAction('editor.action.formatDocument').run()
        editor.updateOptions({
            lineNumbers: 'on'
        });
        """
        evaluateJavascript(javascript)
    }
    
    private func evaluateJavascript(_ javascript: String) {
        webView.evaluateJavaScript(javascript, in: nil, in: WKContentWorld.page) {
          result in
          switch result {
          case .failure(let error):
            print(error)
            break
          case .success(_):
            break
          }
        }
    }
}

// MARK: - Handler

private extension MonacoViewController {
    final class UpdateTextScriptHandler: NSObject, WKScriptMessageHandler {
        private let parent: MonacoViewController

        init(_ parent: MonacoViewController) {
            self.parent = parent
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
            ) {
            guard let text = message.body as? String else {
                fatalError("Unexpected message body")
            }

            parent.delegate?.monacoView(controller: parent, textDidChange: text)
        }
    }
}

// MARK: - Delegate

public protocol MonacoViewControllerDelegate {
    func monacoView(readText controller: MonacoViewController) -> String
    func monacoView(controller: MonacoViewController, textDidChange: String)
}
