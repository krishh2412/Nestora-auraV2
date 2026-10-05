import Foundation
import WebKit

final class WebViewBridge: NSObject, WKScriptMessageHandler {
    weak var webView: WKWebView?

    init(webView: WKWebView) {
        self.webView = webView
        super.init()
        webView.configuration.userContentController.add(self, name: "auraHealth")
    }

    deinit {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "auraHealth")
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let requestId = body["requestId"] as? String,
              let action = body["action"] as? String,
              let payload = body["payload"] as? [String: Any] else { return }

        Task {
            do {
                switch action {
                case "authorize":
                    let types = payload["dataTypes"] as? [String] ?? []
                    try await HealthKitManager.shared.requestAuthorization(keys: types)
                    respond(requestId: requestId, ok: true, data: ["authorized": true], error: nil)

                case "readSnapshot":
                    let types = payload["dataTypes"] as? [String] ?? []
                    let since = (payload["sinceISO"] as? String).flatMap {
                        ISO8601DateFormatter().date(from: $0)
                    }

                    var samples: [[String: Any]] = []
                    for key in types {
                        samples += try await HealthKitManager.shared.readQuantitySamples(key: key, since: since)
                    }
                    respond(requestId: requestId, ok: true, data: ["samples": samples], error: nil)

                default:
                    throw NSError(domain: "AuraBridge", code: 400,
                                  userInfo: [NSLocalizedDescriptionKey: "Unsupported HealthKit action"])
                }
            } catch {
                respond(requestId: requestId, ok: false, data: nil, error: error.localizedDescription)
            }
        }
    }

    private func respond(requestId: String, ok: Bool, data: Any?, error: String?) {
        var body: [String: Any] = ["requestId": requestId, "ok": ok]
        if let data { body["data"] = data }
        if let error { body["error"] = error }

        guard let bytes = try? JSONSerialization.data(withJSONObject: body),
              let json = String(data: bytes, encoding: .utf8) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript("window.AuraNativeHealthResponse(\(json));")
        }
    }
}